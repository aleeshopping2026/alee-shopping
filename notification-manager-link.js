(() => {
  const addLink = async () => {
    const client = window.aleeSupabase;
    if (!client) return;
    const { data } = await client.auth.getSession();
    const email = String(data?.session?.user?.email || "").trim().toLowerCase();
    if (email !== "aleeshopping2026@gmail.com") return;
    const grid = document.querySelector("#content .grid");
    if (!grid || document.getElementById("aleeNotificationManagerCard")) return;
    const card = document.createElement("article");
    card.className = "card";
    card.id = "aleeNotificationManagerCard";
    card.innerHTML = '<h2>දැනුම්දීම් පාලකය</h2><p>අවසර දුන් පාරිභෝගිකයන්ට දීමනා සහ පණිවිඩ දැනුම්දීම් යවන්න.</p><a class="button" href="notification-manager.html">පාලකය විවෘත කරන්න</a>';
    grid.appendChild(card);
  };
  addLink().catch((error) => console.warn("Could not show the notification manager link.", error));
})();
