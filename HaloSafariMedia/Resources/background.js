"use strict";

const sessions = new Map();
let nativePort = null;

function sessionKey(sender) {
  const tabID = sender?.tab?.id ?? "unknown";
  const frameID = sender?.frameId ?? 0;
  return `${tabID}:${frameID}`;
}

function ensureNativePort() {
  if (nativePort) return nativePort;

  try {
    nativePort = browser.runtime.connectNative("com.redstoneinvente.Halo");
    nativePort.onMessage.addListener(handleNativeMessage);
    nativePort.onDisconnect.addListener(() => {
      nativePort = null;
    });
  } catch {
    nativePort = null;
  }

  return nativePort;
}

function pruneSessions(now = Date.now()) {
  for (const [key, entry] of sessions.entries()) {
    if (now - entry.receivedAt > 15000) sessions.delete(key);
  }
}

function chooseSession() {
  pruneSessions();

  const entries = Array.from(sessions.values()).filter((entry) => entry.state?.hasMedia);
  if (!entries.length) return null;

  entries.sort((a, b) => {
    const aPlaying = a.state.playing ? 1 : 0;
    const bPlaying = b.state.playing ? 1 : 0;
    if (aPlaying !== bPlaying) return bPlaying - aPlaying;

    const aVisible = a.state.visibility === "visible" ? 1 : 0;
    const bVisible = b.state.visibility === "visible" ? 1 : 0;
    if (aVisible !== bVisible) return bVisible - aVisible;

    return b.receivedAt - a.receivedAt;
  });

  return entries[0];
}

async function publishSelected() {
  const selected = chooseSession();
  const state = selected?.state || {
    version: 1,
    hasMedia: false,
    pageURL: "",
    host: "",
    title: "",
    artist: "",
    album: "",
    artworkURL: null,
    sourceLabel: "Safari",
    playing: false,
    duration: null,
    position: null,
    playbackRate: 1,
    canPlayPause: false,
    canSeek: false,
    canNext: false,
    canPrevious: false,
    visibility: "hidden",
    updatedAt: Date.now()
  };

  state.updatedAt = Date.now();

  // Safari's documented JavaScript -> native path is sendNativeMessage.
  // connectNative is kept separately so Halo can push commands back to this
  // background script through SFSafariApplication.dispatchMessage.
  try {
    const response = await browser.runtime.sendNativeMessage("com.redstoneinvente.Halo", {
      type: "mediaState",
      payload: state
    });

    if (response?.ok === false) {
      console.error("Halo Safari Media: native bridge rejected media state", response?.error || response);
    }
  } catch (error) {
    console.error("Halo Safari Media: failed to deliver media state to native extension", error);
  }
}

async function sendCommandToSelected(command) {
  const selected = chooseSession();
  if (!selected || !Number.isInteger(selected.tabID)) return;

  const message = {
    type: "haloMediaCommand",
    command: command.command,
    position: command.position
  };

  try {
    if (selected.frameID && selected.frameID !== 0) {
      await browser.tabs.sendMessage(selected.tabID, message, { frameId: selected.frameID });
    } else {
      await browser.tabs.sendMessage(selected.tabID, message);
    }
  } catch {
    // The page may have navigated between the state update and the command.
  }
}

function handleNativeMessage(message) {
  const payload = message?.userInfo || message || {};
  const type = payload.type || message?.name;
  if (type !== "haloMediaCommand" && type !== "HaloSafariMediaCommand") return;

  const command = payload.command ? payload : (payload.userInfo || {});
  if (!command.command) return;
  sendCommandToSelected(command);
}

browser.runtime.onMessage.addListener((message, sender) => {
  if (message?.type !== "haloMediaState" || !message.payload) return undefined;

  const key = sessionKey(sender);
  sessions.set(key, {
    state: { ...message.payload, updatedAt: Date.now() },
    tabID: sender?.tab?.id,
    frameID: sender?.frameId ?? 0,
    receivedAt: Date.now()
  });

  publishSelected();
  return Promise.resolve({ ok: true });
});

if (browser.tabs?.onRemoved) {
  browser.tabs.onRemoved.addListener((tabID) => {
    for (const [key, entry] of sessions.entries()) {
      if (entry.tabID === tabID) sessions.delete(key);
    }
    publishSelected();
  });
}

ensureNativePort();
