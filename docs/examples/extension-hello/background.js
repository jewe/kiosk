// The kiosk force-installs the extension after the page has already loaded (fresh profile at every start),
// and content scripts are not injected into pages that were open before the install. Reload them once.
chrome.runtime.onInstalled.addListener(() => {
  chrome.tabs.query({}, tabs => tabs.forEach(t => chrome.tabs.reload(t.id)));
});
