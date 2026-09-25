(() => {
  "use strict";

  const SEND_INTERVAL_MS = 1000;
  let lastStableSignature = "";
  let lastSentAt = 0;

  function text(selector) {
    const value = document.querySelector(selector)?.textContent?.trim();
    return value || "";
  }

  function attribute(selector, name) {
    return document.querySelector(selector)?.getAttribute(name)?.trim() || "";
  }

  function meta(selector) {
    return document.querySelector(selector)?.content?.trim() || "";
  }

  function mediaElements() {
    return Array.from(document.querySelectorAll("video, audio")).filter((element) => {
      return Number.isFinite(element.duration) || element.readyState > 0 || !element.paused;
    });
  }

  function mediaScore(element) {
    let score = 0;
    if (!element.paused && !element.ended) score += 10000;
    if (element.readyState >= 2) score += 1000;
    if (Number.isFinite(element.duration) && element.duration > 0) score += Math.min(element.duration, 600);
    const rect = element.getBoundingClientRect();
    score += Math.min(Math.max(0, rect.width * rect.height) / 1000, 500);
    return score;
  }

  function activeMedia() {
    return mediaElements().sort((a, b) => mediaScore(b) - mediaScore(a))[0] || null;
  }

  function cleanPageTitle(value) {
    return (value || "")
      .replace(/\s+-\s+YouTube\s*$/i, "")
      .replace(/\s+\|\s+Spotify\s*$/i, "")
      .trim();
  }

  function sourceLabel(host) {
    if (host === "music.youtube.com") return "YouTube Music";
    if (host.endsWith("youtube.com")) return "YouTube";
    if (host === "open.spotify.com") return "Spotify Web";
    if (host.endsWith("soundcloud.com")) return "SoundCloud";
    if (host.endsWith("twitch.tv")) return "Twitch";
    return host || "Safari";
  }

  function metadataFor(media) {
    const host = location.hostname.toLowerCase();
    let title = "";
    let artist = "";
    let album = "";
    let artworkURL = "";
    let allowGenericArtwork = true;

    if (host === "music.youtube.com") {
      title = text("ytmusic-player-bar .title") || text("ytmusic-player-bar .content-info-wrapper .title");
      artist = text("ytmusic-player-bar .byline") || text("ytmusic-player-bar .subtitle");
      artworkURL =
        attribute("ytmusic-player-bar img", "src") ||
        attribute("ytmusic-player-bar img", "data-src");
    } else if (host.endsWith("youtube.com")) {
      title =
        meta('meta[name="title"]') ||
        text("h1.ytd-watch-metadata yt-formatted-string") ||
        text("#title h1");
      artist =
        meta('meta[itemprop="author"]') ||
        attribute('link[itemprop="name"]', "content") ||
        text("#owner #channel-name");

      // Do not fall back to YouTube's site/channel icon. Use the current video's thumbnail
      // as a deterministic fallback while Halo's audio recognition resolves canonical song art.
      // Deriving it from the current video ID also avoids stale og:image values after SPA navigation.
      artworkURL =
        youtubeThumbnailURL() ||
        meta('meta[itemprop="thumbnailUrl"]') ||
        attribute('link[itemprop="thumbnailUrl"]', "href");
      allowGenericArtwork = false;
    } else if (host === "open.spotify.com") {
      const pageTitle = cleanPageTitle(document.title);
      const pieces = pageTitle.split(" • ").map((part) => part.trim()).filter(Boolean);
      title = pieces[0] || "";
      artist = pieces.length > 1 ? pieces[1] : "";
    }

    title =
      title ||
      meta('meta[property="og:title"]') ||
      meta('meta[name="twitter:title"]') ||
      cleanPageTitle(document.title) ||
      "Safari Media";

    artist =
      artist ||
      meta('meta[name="author"]') ||
      meta('meta[property="music:musician"]') ||
      "";

    album = album || meta('meta[property="music:album"]') || "";

    artworkURL =
      artworkURL ||
      (allowGenericArtwork
        ? (
            meta('meta[property="og:image"]') ||
            meta('meta[name="twitter:image"]') ||
            media?.poster ||
            ""
          )
        : "");

    try {
      if (artworkURL) artworkURL = new URL(artworkURL, location.href).href;
    } catch {
      artworkURL = "";
    }

    return { host, title, artist, album, artworkURL };
  }

  function youtubeThumbnailURL() {
    const host = location.hostname.toLowerCase();
    if (!host.endsWith("youtube.com") || host === "music.youtube.com") return "";

    try {
      const url = new URL(location.href);
      let videoID = url.searchParams.get("v") || "";

      if (!videoID) {
        const match = url.pathname.match(/^\/(?:shorts|embed|live)\/([^/?#]+)/i);
        videoID = match?.[1] || "";
      }

      return videoID
        ? `https://i.ytimg.com/vi/${encodeURIComponent(videoID)}/hqdefault.jpg`
        : "";
    } catch {
      return "";
    }
  }

  function siteButton(direction) {
    const host = location.hostname.toLowerCase();
    const selectors = [];

    if (host === "music.youtube.com") {
      selectors.push(
        direction === "next"
          ? "ytmusic-player-bar .next-button"
          : "ytmusic-player-bar .previous-button"
      );
    } else if (host.endsWith("youtube.com")) {
      selectors.push(direction === "next" ? ".ytp-next-button" : ".ytp-prev-button");
    } else if (host === "open.spotify.com") {
      selectors.push(
        direction === "next"
          ? 'button[data-testid="control-button-skip-forward"]'
          : 'button[data-testid="control-button-skip-back"]'
      );
    }

    for (const selector of selectors) {
      const candidate = document.querySelector(selector);
      if (candidate && !candidate.disabled) return candidate;
    }
    return null;
  }

  function buildState() {
    const media = activeMedia();
    const metadata = metadataFor(media);
    const hasMedia = !!media;

    const duration = hasMedia && Number.isFinite(media.duration) && media.duration > 0
      ? media.duration
      : null;
    const position = hasMedia && Number.isFinite(media.currentTime) && media.currentTime >= 0
      ? media.currentTime
      : null;

    return {
      version: 1,
      hasMedia,
      pageURL: location.href,
      host: metadata.host,
      title: metadata.title,
      artist: metadata.artist,
      album: metadata.album,
      artworkURL: metadata.artworkURL || null,
      sourceLabel: sourceLabel(metadata.host),
      playing: hasMedia ? (!media.paused && !media.ended) : false,
      duration,
      position,
      playbackRate: hasMedia && Number.isFinite(media.playbackRate) ? media.playbackRate : 1,
      canPlayPause: hasMedia,
      canSeek: hasMedia && duration !== null && media.seekable?.length > 0,
      canNext: !!siteButton("next"),
      canPrevious: !!siteButton("previous"),
      visibility: document.visibilityState,
      updatedAt: Date.now()
    };
  }

  function stableSignature(state) {
    const copy = { ...state, updatedAt: 0 };
    if (copy.position !== null) copy.position = Math.floor(copy.position);
    return JSON.stringify(copy);
  }

  function sendState(force = false) {
    const state = buildState();
    const signature = stableSignature(state);
    const now = Date.now();

    if (!force && signature === lastStableSignature && (!state.playing || now - lastSentAt < SEND_INTERVAL_MS)) {
      return;
    }

    lastStableSignature = signature;
    lastSentAt = now;

    browser.runtime.sendMessage({
      type: "haloMediaState",
      payload: state
    }).catch(() => {});
  }

  function executeCommand(message) {
    const media = activeMedia();
    if (!media) return false;

    switch (message.command) {
      case "playpause":
        if (media.paused || media.ended) media.play().catch(() => {});
        else media.pause();
        break;
      case "play":
        media.play().catch(() => {});
        break;
      case "pause":
        media.pause();
        break;
      case "seek":
        if (!Number.isFinite(message.position)) return false;
        media.currentTime = Math.max(0, Math.min(Number.isFinite(media.duration) ? media.duration : message.position, message.position));
        break;
      case "next": {
        const button = siteButton("next");
        if (!button) return false;
        button.click();
        break;
      }
      case "previous": {
        const button = siteButton("previous");
        if (!button) return false;
        button.click();
        break;
      }
      default:
        return false;
    }

    setTimeout(() => sendState(true), 80);
    setTimeout(() => sendState(true), 500);
    return true;
  }

  browser.runtime.onMessage.addListener((message) => {
    if (message?.type !== "haloMediaCommand") return undefined;
    return Promise.resolve({ ok: executeCommand(message) });
  });

  for (const eventName of [
    "play", "pause", "ended", "loadedmetadata", "durationchange",
    "ratechange", "seeked", "emptied"
  ]) {
    document.addEventListener(eventName, () => sendState(true), true);
  }

  document.addEventListener("visibilitychange", () => sendState(true), true);

  const observer = new MutationObserver(() => sendState(false));
  observer.observe(document.documentElement || document, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["src", "poster", "title"]
  });

  setInterval(() => sendState(false), SEND_INTERVAL_MS);
  sendState(true);
})();
