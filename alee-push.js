(() => {
  const config = window.ALEE_PUSH_CONFIG;
  const db = window.aleeSupabase;
  let resolveReady;
  let rejectReady;
  const readyPromise = new Promise((resolve, reject) => {
    resolveReady = resolve;
    rejectReady = reject;
    window.aleePush = {
      ready: null,
      sendChat(messageId) {
        if (!messageId || !db || !config?.appId || config.appId === "PASTE_ONESIGNAL_APP_ID_HERE") return Promise.resolve(null);
        return db.functions.invoke(config?.functionName || "alee-push", {
          body: { action: "chat", messageId: String(messageId) },
        }).then(({ data, error }) => {
          if (error) throw error;
          if (data?.error) throw new Error(data.error);
          return data;
        });
      },
    };
    window.aleePush.ready = readyPromise;
  });

  if (!config?.appId || config.appId === "PASTE_ONESIGNAL_APP_ID_HERE") {
    return;
  }

  const functionName = config.functionName || "alee-push";
  let oneSignal = null;
  let currentSession = null;
  let lastRegisteredKey = "";
  let registeredSubscriptionId = "";
  let registrationInFlight = false;

  const preferenceKey = (userId) => "aleePushPreference:" + userId;
  const getPreference = (userId) => {
    try { return localStorage.getItem(preferenceKey(userId)); } catch { return null; }
  };
  const setPreference = (userId, value) => {
    try { localStorage.setItem(preferenceKey(userId), value); } catch { /* Storage may be unavailable. */ }
  };
  const updateNotificationControls = () => {
    const enabled = oneSignal?.User?.PushSubscription?.optedIn === true;
    ["accountNotificationsMenu", "mobileAccountNotifications"].forEach((id) => {
      const button = document.getElementById(id);
      if (button) {
        button.style.display = currentSession?.user?.id ? "" : "none";
        button.innerHTML = `<i class=\"fa-solid fa-bell\"></i> Notifications: ${enabled ? "On" : "Off"}`;
      }
    });
  };

  const askForPushPermission = async () => {
    if (!oneSignal || !("Notification" in window)) return false;
    if (Notification.permission === "denied") {
      window.alert("Notifications are blocked in your browser. Open this site's settings and change Notifications to Allow.");
      return false;
    }
    if (Notification.permission === "default") {
      await oneSignal.Slidedown.promptPush();
    }
    if (Notification.permission !== "granted") return false;
    await oneSignal.User.PushSubscription.optIn();
    if (currentSession?.user?.id) setPreference(currentSession.user.id, "on");
    await registerCurrentSubscription();
    updateNotificationControls();
    return true;
  };

  const invoke = async (action, subscriptionId, session = currentSession) => {
    if (!db || !session?.access_token || !subscriptionId) return null;
    const { data, error } = await db.functions.invoke(functionName, {
      body: { action, subscriptionId },
      headers: { Authorization: "Bearer " + session.access_token },
    });
    if (error) throw error;
    if (data?.error) throw new Error(data.error);
    return data;
  };

  const registerCurrentSubscription = async () => {
    if (!oneSignal || !currentSession?.user?.id || registrationInFlight) return;
    const subscriptionId = oneSignal.User?.PushSubscription?.id;
    const optedIn = oneSignal.User?.PushSubscription?.optedIn;
    if (!subscriptionId || optedIn !== true) return;
    const key = currentSession.user.id + ":" + subscriptionId;
    if (key === lastRegisteredKey) return;
    registrationInFlight = true;
    try {
      if (registeredSubscriptionId && registeredSubscriptionId !== subscriptionId) {
        await invoke("unregister", registeredSubscriptionId, currentSession);
      }
      await invoke("register", subscriptionId, currentSession);
      lastRegisteredKey = key;
      registeredSubscriptionId = subscriptionId;
    } catch (error) {
      console.warn("ALEE push subscription could not be linked to the signed-in account.", error);
    } finally {
      registrationInFlight = false;
    }
  };

  const unregisterCurrentSubscription = async (session) => {
    const subscriptionId = registeredSubscriptionId;
    if (!subscriptionId || !session?.access_token) return;
    try {
      await invoke("unregister", subscriptionId, session);
    } catch (error) {
      console.warn("ALEE push subscription could not be removed from the signed-out account.", error);
    }
    if (registeredSubscriptionId === subscriptionId) {
      registeredSubscriptionId = "";
      lastRegisteredKey = "";
    }
  };

  const setSession = async (session, event = "") => {
    if (session?.user) {
      if (currentSession?.user?.id && currentSession.user.id !== session.user.id) {
        await unregisterCurrentSubscription(currentSession);
      }
      currentSession = session;
      await registerCurrentSubscription();
      if (event === "SIGNED_IN" || event === "INITIAL_SESSION") {
        const promptKey = "aleePushPrompted:" + session.user.id;
        let alreadyPrompted = false;
        try { alreadyPrompted = sessionStorage.getItem(promptKey) === "yes"; } catch { /* Storage may be unavailable. */ }
        if (!alreadyPrompted && getPreference(session.user.id) !== "off" && oneSignal && "Notification" in window && Notification.permission === "default") {
          try { sessionStorage.setItem(promptKey, "yes"); } catch { /* Storage may be unavailable. */ }
          askForPushPermission().catch((error) => console.warn("ALEE push permission prompt failed.", error));
        }
      }
      updateNotificationControls();
      return;
    }
    if (event === "SIGNED_OUT" && currentSession) {
      const previous = currentSession;
      currentSession = null;
      await unregisterCurrentSubscription(previous);
      try { sessionStorage.removeItem("aleePushPrompted:" + previous.user.id); } catch { /* Storage may be unavailable. */ }
      updateNotificationControls();
      return;
    }
    currentSession = null;
    updateNotificationControls();
  };

  window.aleePush.setNotificationsEnabled = async (enabled) => {
    if (!currentSession?.user?.id) {
      window.alert("Please sign in to manage notification settings.");
      return false;
    }
    if (!oneSignal) {
      window.alert("Notifications are still loading. Please try again shortly.");
      return false;
    }
    const userId = currentSession.user.id;
    if (enabled) return askForPushPermission();
    await oneSignal.User.PushSubscription.optOut();
    setPreference(userId, "off");
    await unregisterCurrentSubscription(currentSession);
    updateNotificationControls();
    return true;
  };
  window.aleePush.toggleNotifications = () => window.aleePush.setNotificationsEnabled(oneSignal?.User?.PushSubscription?.optedIn !== true);

  window.OneSignalDeferred = window.OneSignalDeferred || [];
  window.OneSignalDeferred.push(async (sdk) => {
    try {
      const basePath = new URL("./", location.href).pathname;
      const workerPath = basePath.replace(/^\/+/, "") + "OneSignalSDKWorker.js";
      await sdk.init({
        appId: config.appId,
        safari_web_id: config.safariWebId,
        serviceWorkerPath: workerPath,
        serviceWorkerParam: { scope: basePath },
        promptOptions: {
          slidedown: {
            prompts: [{
              type: "push",
              autoPrompt: false,
              text: {
                actionMessage: "Would you like to receive offers and messages from ALEE?",
                acceptButton: "Allow",
                cancelButton: "Not now",
              },
              delay: { pageViews: 1, timeDelay: 12 },
            }],
          },
        },
      });
      oneSignal = sdk;
      resolveReady(sdk);
      sdk.User?.PushSubscription?.addEventListener("change", () => {
        registerCurrentSubscription().catch((error) => console.warn("ALEE push sync failed.", error));
        updateNotificationControls();
      });
      sdk.Notifications?.addEventListener("permissionChange", (allowed) => {
        const permitted = typeof allowed === "boolean" ? allowed : Notification.permission === "granted";
        if (permitted) {
          if (currentSession?.user?.id) setPreference(currentSession.user.id, "on");
          registerCurrentSubscription().catch((error) => console.warn("ALEE push sync failed.", error));
        } else {
          unregisterCurrentSubscription(currentSession);
        }
        updateNotificationControls();
      });

      if (db?.auth) {
        const { data } = await db.auth.getSession();
        await setSession(data?.session || null, "INITIAL_SESSION");
        db.auth.onAuthStateChange((event, session) => {
          window.setTimeout(() => {
            setSession(session || null, event).catch((error) => console.warn("ALEE account notification sync failed.", error));
          }, 0);
        });
      }
    } catch (error) {
      console.error("ALEE web notifications could not start.", error);
      rejectReady(error);
    }
  });

  const sdkScript = document.createElement("script");
  sdkScript.src = "https://cdn.onesignal.com/sdks/web/v16/OneSignalSDK.page.js";
  sdkScript.defer = true;
  sdkScript.onerror = () => {
    const error = new Error("OneSignal's browser library could not be loaded.");
    console.error(error);
    rejectReady(error);
  };
  document.head.appendChild(sdkScript);
})();
