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
      return;
    }
    if (event === "SIGNED_OUT" && currentSession) {
      const previous = currentSession;
      currentSession = null;
      await unregisterCurrentSubscription(previous);
      return;
    }
    currentSession = null;
  };

  window.OneSignalDeferred = window.OneSignalDeferred || [];
  window.OneSignalDeferred.push(async (sdk) => {
    try {
      const basePath = new URL("./", location.href).pathname;
      const workerPath = basePath.replace(/^\/+/, "") + "OneSignalSDKWorker.js";
      await sdk.init({
        appId: config.appId,
        serviceWorkerPath: workerPath,
        serviceWorkerParam: { scope: basePath },
        promptOptions: {
          slidedown: {
            prompts: [{
              type: "push",
              autoPrompt: true,
              text: {
                actionMessage: "ALEE එකෙන් Offer සහ Message Notification එවන්නද?",
                acceptButton: "අවසර දෙන්න",
                cancelButton: "දැන් එපා",
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
      });
      sdk.Notifications?.addEventListener("permissionChange", (allowed) => {
        const permitted = typeof allowed === "boolean" ? allowed : Notification.permission === "granted";
        if (permitted) {
          registerCurrentSubscription().catch((error) => console.warn("ALEE push sync failed.", error));
        } else {
          unregisterCurrentSubscription(currentSession);
        }
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
