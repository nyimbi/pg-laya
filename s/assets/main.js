/* pg-laya docs — main.js (no dependencies) */
(function () {
  "use strict";

  var ICONS = {
    moon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/></svg>',
    sun: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/></svg>'
  };

  /* ---------- theme ---------- */
  var root = document.documentElement;
  function applyTheme(t) {
    root.setAttribute("data-theme", t);
    try { localStorage.setItem("pg-laya-theme", t); } catch (e) {}
    var icon = document.getElementById("theme-icon");
    if (icon) icon.innerHTML = t === "dark" ? ICONS.sun : ICONS.moon;
  }
  var stored = null;
  try { stored = localStorage.getItem("pg-laya-theme"); } catch (e) {}
  var prefersDark = window.matchMedia && window.matchMedia("(prefers-color-scheme: dark)").matches;
  applyTheme(stored || (prefersDark ? "dark" : "light"));

  var themeBtn = document.getElementById("theme-toggle");
  if (themeBtn) themeBtn.addEventListener("click", function () {
    applyTheme(root.getAttribute("data-theme") === "dark" ? "light" : "dark");
  });

  /* ---------- mobile nav ---------- */
  var menuBtn = document.getElementById("menu-btn");
  if (menuBtn) {
    menuBtn.addEventListener("click", function () {
      document.body.classList.toggle("nav-open");
    });
    document.querySelectorAll(".sidebar nav a").forEach(function (a) {
      a.addEventListener("click", function () { document.body.classList.remove("nav-open"); });
    });
  }

  /* ---------- active link ---------- */
  var path = location.pathname.split("/").pop() || "index.html";
  document.querySelectorAll(".sidebar nav a, .header-links a").forEach(function (a) {
    var href = (a.getAttribute("href") || "").split("/").pop();
    if (href === path) a.classList.add("active");
  });

  /* ---------- copy buttons ---------- */
  document.querySelectorAll(".code").forEach(function (block) {
    var pre = block.querySelector("pre");
    if (!pre) return;
    var btn = document.createElement("button");
    btn.className = "copy";
    btn.type = "button";
    btn.textContent = "Copy";
    btn.addEventListener("click", function () {
      var text = pre.textContent;
      function done() {
        btn.textContent = "Copied";
        setTimeout(function () { btn.textContent = "Copy"; }, 1400);
      }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(done, done);
      } else {
        var ta = document.createElement("textarea");
        ta.value = text;
        document.body.appendChild(ta);
        ta.select();
        try { document.execCommand("copy"); } catch (e) {}
        document.body.removeChild(ta);
        done();
      }
    });
    var bar = block.querySelector(".code-bar");
    if (bar) bar.appendChild(btn); else block.appendChild(btn);
  });

  /* ---------- collapsible example cards ---------- */
  document.querySelectorAll(".ex-head").forEach(function (head) {
    head.addEventListener("click", function () {
      head.closest(".ex-card").classList.toggle("open");
    });
  });

  /* ---------- SQL highlighting (safe: text nodes only) ---------- */
  var KW = new Set(("select from where insert into values update set delete create table view " +
    "alter drop extension if not exists cascade and or not null is in on as order by group having " +
    "limit offset distinct join left right inner outer union all default primary key references " +
    "between like ilike any some exists case when then else end true false asc desc interval " +
    "coalesce cast extract date_trunc now current_date current_timestamp").split(" "));
  var FN = new Set(("laya laya_prob laya_choice laya_score laya_score_norm laya_confidence laya_eval " +
    "laya_stats laya_cache_clear laya_version to_json count sum avg min max array width_bucket " +
    "coalesce row_number rank dense_rank lag lead extract date_trunc").split(" "));

  function highlightSql(codeEl) {
    var src = codeEl.textContent;
    var out = "";
    var i = 0;
    var n = src.length;
    function esc(s) {
      return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
    while (i < n) {
      var ch = src[i];
      // line comment
      if (ch === "-" && src[i + 1] === "-") {
        var j = src.indexOf("\n", i);
        if (j === -1) j = n;
        out += '<span class="tok-com">' + esc(src.slice(i, j)) + "</span>";
        i = j;
        continue;
      }
      // string
      if (ch === "'") {
        var k = i + 1;
        while (k < n) {
          if (src[k] === "'" && src[k + 1] === "'") { k += 2; continue; }
          if (src[k] === "'") { k += 1; break; }
          k += 1;
        }
        out += '<span class="tok-str">' + esc(src.slice(i, k)) + "</span>";
        i = k;
        continue;
      }
      // number
      if (/[0-9]/.test(ch) && !/[A-Za-z0-9_]/.test(src[i - 1] || "")) {
        var m = src.slice(i).match(/^[0-9]+(\.[0-9]+)?/);
        if (m) { out += '<span class="tok-num">' + esc(m[0]) + "</span>"; i += m[0].length; continue; }
      }
      // identifier / keyword
      if (/[A-Za-z_]/.test(ch)) {
        var m2 = src.slice(i).match(/^[A-Za-z_][A-Za-z0-9_]*/);
        var word = m2[0];
        var lower = word.toLowerCase();
        if (KW.has(lower)) out += '<span class="tok-kw">' + esc(word) + "</span>";
        else if (FN.has(lower) && src[i + word.length] === "(") out += '<span class="tok-fn">' + esc(word) + "</span>";
        else out += esc(word);
        i += word.length;
        continue;
      }
      out += esc(ch);
      i += 1;
    }
    codeEl.innerHTML = out;
  }

  document.querySelectorAll(".code.lang-sql pre code").forEach(highlightSql);

  /* expose for dynamically injected content */
  window.pgLayaHighlightSql = highlightSql;
})();
