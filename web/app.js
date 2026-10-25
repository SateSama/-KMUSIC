"use strict";

/* ====================================================================
   KMUSIC web: a Subsonic / Navidrome client that installs on the iPhone
   home screen. No build step, no dependencies.
   ==================================================================== */

const ICONS = {
  play: '<svg viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>',
  pause: '<svg viewBox="0 0 24 24"><path d="M6 5h4v14H6zM14 5h4v14h-4z"/></svg>',
  next: '<svg viewBox="0 0 24 24"><path d="M6 18l8.5-6L6 6v12zM16 6v12h2V6h-2z"/></svg>',
  prev: '<svg viewBox="0 0 24 24"><path d="M6 6h2v12H6zM9.5 12l8.5 6V6z"/></svg>',
};

const SORTS = [
  ["newest", "Récents"],
  ["alphabeticalByName", "A–Z"],
  ["frequent", "Fréquents"],
  ["random", "Aléatoire"],
];
const PAGE = 60;

/* ---------------------------------------------------------------- helpers */

const $ = (selector) => document.querySelector(selector);

function h(tag, attrs, ...kids) {
  const el = document.createElement(tag);
  for (const [key, value] of Object.entries(attrs || {})) {
    if (key === "class") el.className = value;
    else if (key.startsWith("on") && typeof value === "function") el.addEventListener(key.slice(2), value);
    else if (value === true) el.setAttribute(key, "");
    else if (value !== false && value != null) el.setAttribute(key, value);
  }
  for (const kid of kids.flat()) {
    if (kid === null || kid === undefined || kid === false) continue;
    el.append(kid.nodeType ? kid : document.createTextNode(String(kid)));
  }
  return el;
}

function clock(seconds) {
  if (!Number.isFinite(seconds) || seconds < 0) return "0:00";
  const total = Math.floor(seconds);
  return Math.floor(total / 60) + ":" + String(total % 60).padStart(2, "0");
}

/* ----------------------------------------------------------------- server */

const store = {
  read() {
    try {
      return JSON.parse(localStorage.getItem("kmusic.server"));
    } catch {
      return null;
    }
  },
  write(value) {
    try {
      localStorage.setItem("kmusic.server", JSON.stringify(value));
    } catch {
      /* private mode: the login just will not be remembered */
    }
  },
  clear() {
    try {
      localStorage.removeItem("kmusic.server");
    } catch {
      /* ignore */
    }
  },
};

/** Remembers the sort order for this visit; works even when browser storage is blocked. */
const prefs = {
  memory: {},
  get(key, fallback) {
    try {
      const value = sessionStorage.getItem("kmusic." + key);
      if (value !== null) return value;
    } catch {
      /* storage blocked: use memory */
    }
    return key in this.memory ? this.memory[key] : fallback;
  },
  set(key, value) {
    this.memory[key] = value;
    try {
      sessionStorage.setItem("kmusic." + key, value);
    } catch {
      /* ignore */
    }
  },
};

let cfg = store.read();

function normalizeUrl(raw) {
  let value = raw.trim();
  if (!/^https?:\/\//i.test(value)) value = "https://" + value;
  return value.replace(/\/+$/, "");
}

function randomSalt() {
  const bytes = new Uint8Array(8);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

function buildUrl(config, method, extra = {}) {
  const params = new URLSearchParams({
    u: config.user,
    t: config.token,
    s: config.salt,
    v: "1.16.1",
    c: "KMUSIC",
    f: "json",
    ...extra,
  });
  return `${config.url}/rest/${method}.view?${params}`;
}

function jsonp(config, method, extra) {
  return new Promise((resolve, reject) => {
    const name = "kmusic_cb_" + Math.random().toString(36).slice(2);
    const script = document.createElement("script");
    let timer = 0;
    const done = () => {
      delete window[name];
      script.remove();
      clearTimeout(timer);
    };
    const fail = () => {
      done();
      reject(new Error("Impossible de joindre le serveur. Vérifie l'adresse (en https://) et qu'il est accessible depuis Internet."));
    };
    timer = setTimeout(fail, 15000);
    window[name] = (data) => {
      done();
      resolve(data);
    };
    script.onerror = fail;
    script.src = buildUrl(config, method, { ...extra, f: "jsonp", callback: name });
    document.head.append(script);
  });
}

async function call(config, method, extra) {
  if (location.protocol === "https:" && config.url.startsWith("http://")) {
    throw new Error("Cette page est en https : ton serveur doit aussi répondre en https:// (un simple http:// est bloqué par le navigateur).");
  }
  let data;
  try {
    const response = await fetch(buildUrl(config, method, extra));
    if (!response.ok) throw new Error("Le serveur a répondu avec l'erreur " + response.status + ".");
    data = await response.json();
  } catch (error) {
    // A network/CORS failure is a TypeError: retry through JSONP, which has no CORS rule.
    if (error && error.name === "TypeError") data = await jsonp(config, method, extra);
    else throw error;
  }
  const result = data && data["subsonic-response"];
  if (!result) throw new Error("Réponse inattendue du serveur.");
  if (result.status !== "ok") throw new Error((result.error && result.error.message) || "Erreur du serveur.");
  return result;
}

const coverUrl = (id, size = 300) => (cfg && id ? buildUrl(cfg, "getCoverArt", { id, size }) : "");
const streamUrl = (id) => buildUrl(cfg, "stream", { id });

/* ----------------------------------------------------------------- player */

const Player = {
  audio: new Audio(),
  queue: [],
  index: -1,
  seeking: false,

  get song() {
    return this.queue[this.index] || null;
  },

  play(songs, start = 0) {
    if (!songs.length) return;
    this.queue = songs;
    this.load(start);
  },

  load(index) {
    this.index = index;
    const song = this.song;
    if (!song) return;
    this.audio.src = streamUrl(song.id);
    this.audio.play().catch(() => {});
    this.publish(song);
    this.render();
  },

  toggle() {
    if (!this.song) return;
    if (this.audio.paused) this.audio.play().catch(() => {});
    else this.audio.pause();
  },

  next() {
    if (this.index + 1 < this.queue.length) this.load(this.index + 1);
    else this.audio.pause();
  },

  previous() {
    if (this.audio.currentTime > 3 || this.index === 0) this.audio.currentTime = 0;
    else this.load(this.index - 1);
  },

  seek(seconds) {
    if (Number.isFinite(seconds)) this.audio.currentTime = seconds;
  },

  /** Lock screen / Control Center. */
  publish(song) {
    if (!("mediaSession" in navigator)) return;
    navigator.mediaSession.metadata = new MediaMetadata({
      title: song.title,
      artist: song.artist || "",
      album: song.album || "",
      artwork: song.coverArt
        ? [{ src: coverUrl(song.coverArt, 512), sizes: "512x512", type: "image/jpeg" }]
        : [],
    });
  },

  render() {
    const song = this.song;
    const dock = $("#mini");
    dock.hidden = !song;
    if (!song) return;
    const playing = !this.audio.paused;
    $("#mini-title").textContent = song.title;
    $("#mini-artist").textContent = song.artist || "";
    $("#mini-cover").src = coverUrl(song.coverArt, 100);
    $("#mini-toggle").innerHTML = playing ? ICONS.pause : ICONS.play;
    $("#full-title").textContent = song.title;
    $("#full-artist").textContent = song.artist || "";
    $("#full-cover").src = coverUrl(song.coverArt, 600);
    $("#full-toggle").innerHTML = playing ? ICONS.pause : ICONS.play;
    if ("mediaSession" in navigator) navigator.mediaSession.playbackState = playing ? "playing" : "paused";
    document.querySelectorAll(".row[data-id]").forEach((row) => {
      row.classList.toggle("playing", row.dataset.id === song.id);
    });
  },

  tick() {
    const duration = Number.isFinite(this.audio.duration) ? this.audio.duration : Number((this.song || {}).duration) || 0;
    const seek = $("#full-seek");
    if (!this.seeking) {
      seek.max = String(Math.max(duration, 1));
      seek.value = String(this.audio.currentTime);
      $("#full-pos").textContent = clock(this.audio.currentTime);
    }
    $("#full-dur").textContent = clock(duration);
    if ("mediaSession" in navigator && duration > 0) {
      try {
        navigator.mediaSession.setPositionState({
          duration,
          position: Math.min(this.audio.currentTime, duration),
          playbackRate: this.audio.playbackRate || 1,
        });
      } catch {
        /* not supported everywhere */
      }
    }
  },

  init() {
    const audio = this.audio;
    audio.preload = "auto";
    audio.setAttribute("playsinline", "");
    audio.addEventListener("play", () => this.render());
    audio.addEventListener("pause", () => this.render());
    audio.addEventListener("ended", () => this.next());
    audio.addEventListener("timeupdate", () => this.tick());
    audio.addEventListener("loadedmetadata", () => this.tick());

    $("#mini-toggle").addEventListener("click", () => this.toggle());
    $("#mini-next").addEventListener("click", () => this.next());
    $("#mini-toggle").innerHTML = ICONS.play;
    $("#mini-next").innerHTML = ICONS.next;
    $("#full-prev").innerHTML = ICONS.prev;
    $("#full-next").innerHTML = ICONS.next;
    $("#full-toggle").innerHTML = ICONS.play;
    $("#full-toggle").addEventListener("click", () => this.toggle());
    $("#full-next").addEventListener("click", () => this.next());
    $("#full-prev").addEventListener("click", () => this.previous());

    // Open / close the big player.
    $("#mini").addEventListener("click", (event) => {
      if (event.target.closest("button")) return;
      $("#full").hidden = false;
    });
    $("#full-close").addEventListener("click", () => {
      $("#full").hidden = true;
    });

    const seek = $("#full-seek");
    seek.addEventListener("input", () => {
      this.seeking = true;
      $("#full-pos").textContent = clock(Number(seek.value));
    });
    seek.addEventListener("change", () => {
      this.seek(Number(seek.value));
      this.seeking = false;
    });

    if ("mediaSession" in navigator) {
      const session = navigator.mediaSession;
      const set = (action, handler) => {
        try {
          session.setActionHandler(action, handler);
        } catch {
          /* action not supported */
        }
      };
      set("play", () => this.audio.play().catch(() => {}));
      set("pause", () => this.audio.pause());
      set("previoustrack", () => this.previous());
      set("nexttrack", () => this.next());
      set("seekto", (details) => this.seek(details.seekTime));
      set("seekbackward", (details) => this.seek(this.audio.currentTime - (details.seekOffset || 10)));
      set("seekforward", (details) => this.seek(this.audio.currentTime + (details.seekOffset || 10)));
    }
  },
};

/* ------------------------------------------------------------------ views */

const view = $("#view");
let renderId = 0;

function setTab(name) {
  document.querySelectorAll("#tabs a").forEach((a) => a.classList.toggle("active", a.dataset.tab === name));
}

function songRow(song, number, songs, index) {
  return h(
    "button",
    {
      class: "row" + (Player.song && Player.song.id === song.id ? " playing" : ""),
      "data-id": song.id,
      onclick: () => Player.play(songs, index),
    },
    h("span", { class: "num" }, number),
    h("div", { class: "info" }, h("b", {}, song.title), h("span", {}, [song.artist, song.album].filter(Boolean).join(" · "))),
    h("span", { class: "time" }, song.duration ? clock(song.duration) : ""),
  );
}

function albumCard(album) {
  return h(
    "a",
    { class: "card", href: "#/album/" + encodeURIComponent(album.id) },
    h("img", { class: "cover", loading: "lazy", alt: "", src: coverUrl(album.coverArt, 300) }),
    h("b", {}, album.name),
    h("span", {}, album.artist || ""),
  );
}

function showLogin() {
  $("#dock").hidden = true;
  $("#logout").hidden = true;
  const error = h("p", { class: "error" });
  const url = h("input", { type: "url", placeholder: "Adresse du serveur (https://...)", autocapitalize: "none", autocorrect: "off", required: true });
  const user = h("input", { type: "text", placeholder: "Nom d'utilisateur", autocapitalize: "none", autocorrect: "off", autocomplete: "username", required: true });
  const pass = h("input", { type: "password", placeholder: "Mot de passe", autocomplete: "current-password", required: true });
  const button = h("button", { class: "btn", type: "submit" }, "Se connecter");
  const standalone =
    window.navigator.standalone === true ||
    (typeof window.matchMedia === "function" && window.matchMedia("(display-mode: standalone)").matches);

  const form = h(
    "form",
    {
      onsubmit: async (event) => {
        event.preventDefault();
        error.textContent = "";
        button.disabled = true;
        button.textContent = "Connexion...";
        const salt = randomSalt();
        const candidate = {
          url: normalizeUrl(url.value),
          user: user.value.trim(),
          salt,
          token: md5(pass.value + salt),
        };
        try {
          await call(candidate, "ping");
          cfg = candidate;
          store.write(cfg);
          pass.value = "";
          location.hash = "#/";
          route();
        } catch (failure) {
          error.textContent = failure.message;
          button.disabled = false;
          button.textContent = "Se connecter";
        }
      },
    },
    url,
    user,
    pass,
    button,
  );

  view.replaceChildren(
    h(
      "div",
      { class: "login" },
      h("div", { class: "brand" }, "KMUSIC"),
      h("p", {}, "Connecte ton serveur Navidrome / Subsonic"),
      form,
      error,
      standalone ? null : h("p", { class: "tip" }, "Astuce iPhone : touche Partager, puis « Sur l'écran d'accueil » pour installer KMUSIC comme une appli."),
    ),
  );
}

async function showAlbums() {
  setTab("albums");
  const mine = ++renderId;
  let sort = prefs.get("sort", "newest");
  let albums = [];
  let finished = false;
  let busy = false;

  const grid = h("div", { class: "grid" });
  const status = h("p", { class: "status" });
  const more = h("button", { class: "btn ghost", hidden: true, onclick: () => load() }, "Charger plus");
  const bar = h("div", { class: "segmented" });

  const drawBar = () =>
    bar.replaceChildren(
      ...SORTS.map(([key, label]) =>
        h(
          "button",
          {
            class: key === sort ? "active" : "",
            onclick: () => {
              sort = key;
              prefs.set("sort", key);
              drawBar();
              reset();
            },
          },
          label,
        ),
      ),
    );

  async function load() {
    if (busy || finished) return;
    busy = true;
    status.textContent = "Chargement...";
    more.hidden = true;
    const type = sort;
    try {
      const result = await call(cfg, "getAlbumList2", { type, size: PAGE, offset: albums.length });
      if (mine !== renderId || type !== sort) return;
      const page = (result.albumList2 && result.albumList2.album) || [];
      const known = new Set(albums.map((a) => a.id));
      const fresh = page.filter((a) => !known.has(a.id));
      albums = albums.concat(fresh);
      grid.append(...fresh.map(albumCard));
      finished = page.length < PAGE || type === "random";
      status.textContent = albums.length ? "" : "Aucun album.";
      more.hidden = finished;
    } catch (failure) {
      if (mine === renderId) status.textContent = failure.message;
    } finally {
      if (mine === renderId && type === sort) busy = false;
    }
  }

  function reset() {
    albums = [];
    finished = false;
    busy = false;
    grid.replaceChildren();
    load();
  }

  drawBar();
  view.replaceChildren(bar, grid, status, more);
  load();
}

async function showAlbum(id) {
  setTab("albums");
  const mine = ++renderId;
  view.replaceChildren(h("p", { class: "status" }, "Chargement..."));
  try {
    const result = await call(cfg, "getAlbum", { id });
    if (mine !== renderId) return;
    const album = result.album;
    const songs = album.song || [];
    view.replaceChildren(
      h(
        "div",
        { class: "album-head" },
        h("img", { alt: "", src: coverUrl(album.coverArt, 600) }),
        h("h2", {}, album.name),
        h("p", {}, album.artist || ""),
      ),
      h(
        "div",
        { class: "actions" },
        h("button", { class: "btn", onclick: () => Player.play(songs, 0) }, "Lecture"),
        h(
          "button",
          {
            class: "btn ghost",
            onclick: () => Player.play([...songs].sort(() => Math.random() - 0.5), 0),
          },
          "Aléatoire",
        ),
      ),
      h("div", { class: "list" }, songs.map((song, i) => songRow(song, song.track || i + 1, songs, i))),
    );
  } catch (failure) {
    if (mine === renderId) view.replaceChildren(h("p", { class: "status" }, failure.message));
  }
}

function showSearch() {
  setTab("search");
  const mine = ++renderId;
  const results = h("div", {});
  const input = h("input", { type: "search", placeholder: "Albums, titres", autocapitalize: "none", autocorrect: "off" });
  let timer = 0;
  let last = "";

  input.addEventListener("input", () => {
    clearTimeout(timer);
    timer = setTimeout(run, 350);
  });

  async function run() {
    const query = input.value.trim();
    if (query === last) return;
    last = query;
    if (!query) {
      results.replaceChildren();
      return;
    }
    try {
      const result = await call(cfg, "search3", { query, artistCount: 0, albumCount: 20, songCount: 30 });
      if (mine !== renderId || query !== last) return;
      const found = result.searchResult3 || {};
      const albums = found.album || [];
      const songs = found.song || [];
      results.replaceChildren(
        albums.length ? h("h2", { class: "section" }, "Albums") : null,
        h("div", { class: "grid" }, albums.map(albumCard)),
        songs.length ? h("h2", { class: "section" }, "Titres") : null,
        h("div", { class: "list" }, songs.map((song, i) => songRow(song, i + 1, songs, i))),
        !albums.length && !songs.length ? h("p", { class: "status" }, "Aucun résultat.") : null,
      );
    } catch (failure) {
      if (mine === renderId) results.replaceChildren(h("p", { class: "status" }, failure.message));
    }
  }

  view.replaceChildren(h("div", { class: "search" }, input), results);
}

function route() {
  if (!cfg) {
    showLogin();
    return;
  }
  $("#dock").hidden = false;
  $("#logout").hidden = false;
  const hash = location.hash || "#/";
  const album = hash.match(/^#\/album\/(.+)$/);
  if (album) showAlbum(decodeURIComponent(album[1]));
  else if (hash.startsWith("#/search")) showSearch();
  else showAlbums();
  window.scrollTo(0, 0);
}

/* ------------------------------------------------------------------- boot */

$("#logout").addEventListener("click", () => {
  Player.audio.pause();
  Player.queue = [];
  Player.index = -1;
  Player.render();
  store.clear();
  cfg = null;
  location.hash = "";
  route();
});

window.addEventListener("hashchange", route);
Player.init();
route();

if ("serviceWorker" in navigator) {
  window.addEventListener("load", () => {
    navigator.serviceWorker.register("sw.js").catch(() => {});
  });
}
