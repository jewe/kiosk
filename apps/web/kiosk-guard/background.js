// Kiosk guard (apps/web/kiosk-guard, blocked page apps/web/blocked.html): a way back from pages blocked by chrome.allowed_domains (policy URLBlocklist "*").
// Chrome alone shows "This page has been blocked" with no way back, since kiosk mode has no back button.
// When a top-level navigation fails with ERR_BLOCKED_BY_ADMINISTRATOR, the tab is sent to the kiosk's
// blocked page (served by the local nginx, which is always allowed). That page counts down and goes back
// to the last allowed page. A new window that a link opened and that has no allowed page to return to
// is closed instead.
// config.js is written by apps/web/extensions.sh: self.KIOSK_GUARD = { returnAfter: <seconds> }
importScripts("config.js");
const CFG = Object.assign({ returnAfter: 5 }, self.KIOSK_GUARD || {});
const PAGE = "http://127.0.0.1:8090/_kiosk/blocked.html";

// The service worker is stopped when idle, so the last allowed URL per tab lives in session storage.
const key = tabId => "last:" + tabId;
function remember(d) {
  if (d.frameId !== 0 || !/^https?:/.test(d.url) || d.url.startsWith(PAGE)) return;
  chrome.storage.session.set({ [key(d.tabId)]: d.url });
}
chrome.webNavigation.onCompleted.addListener(remember);
chrome.webNavigation.onHistoryStateUpdated.addListener(remember);   // single-page apps (pushState)
chrome.tabs.onRemoved.addListener(tabId => chrome.storage.session.remove(key(tabId)));

chrome.webNavigation.onErrorOccurred.addListener(async d => {
  if (d.frameId !== 0 || !/BLOCKED_BY_ADMINISTRATOR/.test(d.error)) return;
  const back = (await chrome.storage.session.get(key(d.tabId)))[key(d.tabId)] || "";
  const tabs = await chrome.tabs.query({});
  const close = !back && tabs.length > 1;   // opened by a link (target=_blank, window.open)
  const q = new URLSearchParams({ t: String(CFG.returnAfter), back, close: close ? "1" : "0" });
  chrome.tabs.update(d.tabId, { url: PAGE + "?" + q });
  if (close) setTimeout(() => chrome.tabs.remove(d.tabId).catch(() => {}), Math.max(0, CFG.returnAfter) * 1000);
});
