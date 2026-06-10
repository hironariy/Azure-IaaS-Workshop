---
title: Azure IaaS Workshop 受講者ポータル
---

# Azure IaaS Workshop 受講者ポータル

<p class="wp-lead">このポータルは、2 日版 Azure IaaS Workshop を進めるための受講者向け入口です。CLI とスクリプト作業は <strong>Azure Cloud Shell (Bash)</strong> を標準にし、ローカル PC にはブラウザ以外のツールを原則として要求しません。</p>

<style>
  /* =====================================================================
     Azure IaaS Workshop 受講者ポータル — 2 ペインレイアウト
     すべて自己完結（インライン）。minima テーマ上で動作。
     ===================================================================== */
  :root {
    --wp-brand: #0078d4;
    --wp-brand-dark: #005a9e;
    --wp-brand-darker: #004578;
    --wp-accent: #3ba0e6;
    --wp-page: #f4f7fb;
    --wp-surface: #ffffff;
    --wp-surface-2: #f8fafc;
    --wp-border: #e3e8ef;
    --wp-border-strong: #cdd5e0;
    --wp-text: #1b2430;
    --wp-muted: #5b6675;
    --wp-done: #107c10;
    --wp-done-soft: #e8f4e8;
    --wp-pre: #64748b;
    --wp-d0: #8661c5;
    --wp-d1: #0078d4;
    --wp-d2: #0e8f8a;
    --wp-radius: 14px;
    --wp-radius-sm: 9px;
    --wp-shadow: 0 1px 2px rgba(16, 24, 40, .06), 0 4px 12px rgba(16, 24, 40, .06);
    --wp-shadow-sm: 0 1px 2px rgba(16, 24, 40, .07);
  }

  .page-content > .wrapper {
    max-width: 1320px;
  }

  .wp-lead {
    margin: 1.1rem 0 0;
    padding: .9rem 1.1rem;
    border: 1px solid var(--wp-border);
    border-left: 4px solid var(--wp-brand);
    border-radius: var(--wp-radius-sm);
    background: linear-gradient(180deg, #f3f9ff, var(--wp-surface));
    color: var(--wp-muted);
    font-size: 1.02rem;
    line-height: 1.75;
  }

  .workshop-portal {
    display: grid;
    grid-template-columns: minmax(23rem, 34%) minmax(0, 1fr);
    gap: 1.25rem;
    align-items: start;
    margin-top: 1.5rem;
  }

  /* ---- TOC (left pane) ---- */
  .workshop-toc {
    position: sticky;
    top: 1rem;
    max-height: 86vh;
    overflow: auto;
    padding: 1.1rem 1.1rem 1.25rem;
    border: 1px solid var(--wp-border);
    border-radius: var(--wp-radius);
    background: var(--wp-page);
    box-shadow: var(--wp-shadow);
  }

  .workshop-toc::-webkit-scrollbar {
    width: 10px;
  }

  .workshop-toc::-webkit-scrollbar-thumb {
    border: 2px solid var(--wp-page);
    border-radius: 8px;
    background: var(--wp-border-strong);
  }

  .wp-toc-title {
    display: flex;
    align-items: center;
    gap: .55rem;
    margin: .2rem 0 .35rem;
    font-size: 1.05rem;
    font-weight: 700;
    color: var(--wp-text);
  }

  .wp-toc-title .wp-dot {
    width: .55rem;
    height: .55rem;
    border-radius: 50%;
    background: var(--wp-brand);
    box-shadow: 0 0 0 3px rgba(0, 120, 212, .15);
  }

  .wp-toc-sub .wp-dot {
    background: var(--wp-muted);
    box-shadow: 0 0 0 3px rgba(91, 102, 117, .15);
  }

  .wp-toc-note {
    margin: 0 0 .9rem;
    font-size: .83rem;
    line-height: 1.6;
    color: var(--wp-muted);
  }

  .wp-toc-sub {
    margin-top: 1.5rem;
  }

  /* ---- progress ---- */
  .wp-progress {
    margin-bottom: 1rem;
    padding: .7rem .85rem .8rem;
    border: 1px solid var(--wp-border);
    border-radius: var(--wp-radius-sm);
    background: var(--wp-surface);
    box-shadow: var(--wp-shadow-sm);
  }

  .wp-progress__head {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: .5rem;
  }

  .wp-progress__label {
    font-size: .9rem;
    font-weight: 700;
    color: var(--wp-text);
  }

  .wp-progress__count {
    font-size: .85rem;
    color: var(--wp-muted);
  }

  .wp-progress__count strong {
    font-size: 1rem;
    color: var(--wp-brand-dark);
  }

  .wp-progress__bar {
    height: .5rem;
    margin: .55rem 0 .55rem;
    border-radius: 999px;
    background: #e6ebf2;
    overflow: hidden;
  }

  .wp-progress__fill {
    width: 0;
    height: 100%;
    border-radius: inherit;
    background: linear-gradient(90deg, var(--wp-brand), var(--wp-accent));
    transition: width .35s ease;
  }

  .wp-progress__reset {
    appearance: none;
    padding: .25rem .6rem;
    border: 1px solid var(--wp-border-strong);
    border-radius: 7px;
    background: var(--wp-surface);
    color: var(--wp-muted);
    font-size: .78rem;
    cursor: pointer;
    transition: color .15s, border-color .15s;
  }

  .wp-progress__reset:hover {
    color: var(--wp-brand-dark);
    border-color: var(--wp-brand);
  }

  .wp-progress__reset:focus-visible {
    outline: 3px solid var(--wp-accent);
    outline-offset: 2px;
  }

  /* ---- step list (progress TOC) ---- */
  .wp-steps,
  .wp-refs {
    display: flex;
    flex-direction: column;
    gap: .5rem;
    margin: 0;
    padding: 0;
    list-style: none;
  }

  .wp-step {
    position: relative;
    display: grid;
    grid-template-columns: auto 1fr auto;
    align-items: center;
    gap: .7rem;
    padding: .6rem .75rem;
    border: 1px solid var(--wp-border);
    border-radius: var(--wp-radius-sm);
    background: var(--wp-surface);
    box-shadow: var(--wp-shadow-sm);
    transition: border-color .15s, box-shadow .15s, transform .15s;
  }

  .wp-step:hover {
    border-color: var(--wp-accent);
    box-shadow: var(--wp-shadow);
    transform: translateY(-1px);
  }

  .wp-step__num {
    display: grid;
    place-content: center;
    width: 1.9rem;
    height: 1.9rem;
    border-radius: 50%;
    background: linear-gradient(145deg, var(--wp-brand), var(--wp-brand-darker));
    color: #fff;
    font-size: .95rem;
    font-weight: 700;
    box-shadow: inset 0 0 0 1px rgba(255, 255, 255, .18);
  }

  .wp-step__body,
  .wp-ref__body {
    display: flex;
    flex-direction: column;
    gap: .25rem;
    min-width: 0;
  }

  .wp-step__link,
  .wp-ref__link {
    font-weight: 600;
    line-height: 1.35;
    color: var(--wp-brand-dark);
    text-decoration: none;
  }

  .wp-step__link:hover,
  .wp-ref__link:hover {
    color: var(--wp-brand);
    text-decoration: underline;
  }

  .wp-step__link:focus-visible,
  .wp-ref__link:focus-visible {
    outline: 3px solid var(--wp-accent);
    outline-offset: 3px;
    border-radius: 3px;
  }

  .wp-badge {
    align-self: flex-start;
    padding: .12rem .5rem;
    border-radius: 999px;
    background: var(--wp-pre);
    color: #fff;
    font-size: .68rem;
    font-weight: 700;
    letter-spacing: .02em;
  }

  .wp-badge--pre { background: var(--wp-pre); }
  .wp-badge--d0 { background: var(--wp-d0); }
  .wp-badge--d1 { background: var(--wp-d1); }
  .wp-badge--d2 { background: var(--wp-d2); }

  /* ---- active / done states ---- */
  .wp-step.is-active,
  .wp-ref.is-active {
    border-color: var(--wp-brand);
    box-shadow: 0 0 0 1px var(--wp-brand), var(--wp-shadow);
    background: linear-gradient(0deg, var(--wp-surface), #f1f8ff);
  }

  .wp-step.is-active::before,
  .wp-ref.is-active::before {
    content: "";
    position: absolute;
    left: 0;
    top: 14%;
    bottom: 14%;
    width: 3px;
    border-radius: 0 3px 3px 0;
    background: var(--wp-brand);
  }

  .wp-step.is-done {
    border-color: #c4e3c4;
    background: var(--wp-done-soft);
  }

  .wp-step.is-done .wp-step__num {
    background: linear-gradient(145deg, #1aa31a, var(--wp-done));
  }

  .wp-step.is-done .wp-step__link {
    color: #4a6b4a;
  }

  /* ---- custom checkbox ---- */
  .wp-check {
    display: inline-flex;
  }

  .workshop-toc input[type="checkbox"] {
    appearance: none;
    -webkit-appearance: none;
    display: grid;
    place-content: center;
    width: 1.4rem;
    height: 1.4rem;
    margin: 0;
    border: 2px solid var(--wp-border-strong);
    border-radius: 6px;
    background: var(--wp-surface);
    cursor: pointer;
    transition: background .15s, border-color .15s;
  }

  .workshop-toc input[type="checkbox"]::after {
    content: "";
    width: .42rem;
    height: .78rem;
    margin-top: -.12rem;
    border: solid #fff;
    border-width: 0 .18rem .18rem 0;
    transform: rotate(45deg) scale(0);
    transform-origin: center;
    transition: transform .15s ease;
  }

  .workshop-toc input[type="checkbox"]:hover {
    border-color: var(--wp-brand);
  }

  .workshop-toc input[type="checkbox"]:checked {
    border-color: var(--wp-done);
    background: var(--wp-done);
  }

  .workshop-toc input[type="checkbox"]:checked::after {
    transform: rotate(45deg) scale(1);
  }

  .workshop-toc input[type="checkbox"]:focus-visible {
    outline: 3px solid var(--wp-accent);
    outline-offset: 2px;
  }

  /* ---- reference list ---- */
  .wp-ref {
    position: relative;
    display: grid;
    grid-template-columns: 1fr auto;
    align-items: center;
    gap: .7rem;
    padding: .55rem .75rem;
    border: 1px solid var(--wp-border);
    border-left: 3px solid var(--wp-border-strong);
    border-radius: var(--wp-radius-sm);
    background: var(--wp-surface);
    box-shadow: var(--wp-shadow-sm);
    transition: border-color .15s, box-shadow .15s;
  }

  .wp-ref:hover {
    border-left-color: var(--wp-brand);
    box-shadow: var(--wp-shadow);
  }

  .wp-ref__use {
    font-size: .72rem;
    font-weight: 600;
    letter-spacing: .02em;
    color: var(--wp-muted);
  }

  /* ---- content (right pane) ---- */
  .workshop-content {
    min-height: 86vh;
    overflow: hidden;
    border: 1px solid var(--wp-border);
    border-radius: var(--wp-radius);
    background: var(--wp-surface);
    box-shadow: var(--wp-shadow);
  }

  .workshop-content iframe {
    display: block;
    width: 100%;
    height: 86vh;
    border: 0;
  }

  /* ---- responsive ---- */
  @media (max-width: 900px) {
    .workshop-portal {
      grid-template-columns: 1fr;
    }

    .workshop-toc {
      position: static;
      max-height: none;
    }

    .workshop-content iframe {
      height: 72vh;
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .workshop-portal *,
    .workshop-toc * {
      transition: none !important;
      animation: none !important;
    }
  }
</style>

<div class="workshop-portal">
  <nav class="workshop-toc" aria-label="ワークショップ教材 TOC">
    <h2 class="wp-toc-title"><span class="wp-dot" aria-hidden="true"></span>ワークショップ進行 TOC</h2>
    <p class="wp-toc-note">上から順に進めます。右側のチェックは進捗確認用で、ブラウザに自動保存されます（リロードしても保持）。</p>

    <div class="wp-progress">
      <div class="wp-progress__head">
        <span class="wp-progress__label">進捗</span>
        <span class="wp-progress__count"><strong data-progress-count>0</strong> / <span data-progress-total>7</span> 完了</span>
      </div>
      <div class="wp-progress__bar" role="progressbar" aria-label="ワークショップ進捗" aria-valuemin="0" aria-valuemax="7" aria-valuenow="0">
        <div class="wp-progress__fill" data-progress-fill></div>
      </div>
      <button type="button" class="wp-progress__reset" data-progress-reset>進捗をリセット</button>
    </div>

    <ol class="wp-steps">
      <li class="wp-step" data-page="learner/learner-quickstart.ja.html">
        <span class="wp-step__num" aria-hidden="true">1</span>
        <span class="wp-step__body">
          <span class="wp-badge wp-badge--pre">事前確認</span>
          <a class="wp-step__link" href="learner/learner-quickstart.ja.html" target="workshop-content-frame">受講者クイックスタート</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="quickstart" aria-label="受講者クイックスタート完了"></label>
      </li>
      <li class="wp-step" data-page="learner/day-0-prerequisites.ja.html">
        <span class="wp-step__num" aria-hidden="true">2</span>
        <span class="wp-step__body">
          <span class="wp-badge wp-badge--d0">Day 0</span>
          <a class="wp-step__link" href="learner/day-0-prerequisites.ja.html" target="workshop-content-frame">Day 0: 事前準備</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="day0" aria-label="Day 0 事前準備完了"></label>
      </li>
      <li class="wp-step" data-page="learner/azure-cloud-shell-guide.ja.html">
        <span class="wp-step__num" aria-hidden="true">3</span>
        <span class="wp-step__body">
          <span class="wp-badge wp-badge--d1">Day 1 開始</span>
          <a class="wp-step__link" href="learner/azure-cloud-shell-guide.ja.html" target="workshop-content-frame">Azure Cloud Shell ガイド</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="cloudshell" aria-label="Azure Cloud Shell ガイド完了"></label>
      </li>
      <li class="wp-step" data-page="learner/day-1-deployment-checklist.ja.html">
        <span class="wp-step__num" aria-hidden="true">4</span>
        <span class="wp-step__body">
          <span class="wp-badge wp-badge--d1">Day 1 本編</span>
          <a class="wp-step__link" href="learner/day-1-deployment-checklist.ja.html" target="workshop-content-frame">Day 1: デプロイチェックリスト</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="day1" aria-label="Day 1 デプロイチェックリスト完了"></label>
      </li>
      <li class="wp-step" data-page="operations/monitoring-guide.ja.html">
        <span class="wp-step__num" aria-hidden="true">5</span>
        <span class="wp-step__body">
          <span class="wp-badge wp-badge--d1">Day 1 監視</span>
          <a class="wp-step__link" href="operations/monitoring-guide.ja.html" target="workshop-content-frame">監視ガイド</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="monitoring" aria-label="監視ガイド完了"></label>
      </li>
      <li class="wp-step" data-page="learner/day-2-resiliency-checklist.ja.html">
        <span class="wp-step__num" aria-hidden="true">6</span>
        <span class="wp-step__body">
          <span class="wp-badge wp-badge--d2">Day 2 本編</span>
          <a class="wp-step__link" href="learner/day-2-resiliency-checklist.ja.html" target="workshop-content-frame">Day 2: 回復性チェックリスト</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="day2" aria-label="Day 2 回復性チェックリスト完了"></label>
      </li>
      <li class="wp-step" data-page="operations/disaster-recovery-guide.ja.html">
        <span class="wp-step__num" aria-hidden="true">7</span>
        <span class="wp-step__body">
          <span class="wp-badge wp-badge--d2">Day 2 補足</span>
          <a class="wp-step__link" href="operations/disaster-recovery-guide.ja.html" target="workshop-content-frame">災害復旧ガイド</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="dr" aria-label="災害復旧ガイド完了"></label>
      </li>
    </ol>

    <h2 class="wp-toc-title wp-toc-sub"><span class="wp-dot" aria-hidden="true"></span>迷ったときの参照 TOC</h2>
    <p class="wp-toc-note">順番に関係なく、必要なときに開く参照ページです。</p>

    <ul class="wp-refs">
      <li class="wp-ref" data-page="operations/troubleshooting-runbook.ja.html">
        <span class="wp-ref__body">
          <span class="wp-ref__use">症状別の切り分け</span>
          <a class="wp-ref__link" href="operations/troubleshooting-runbook.ja.html" target="workshop-content-frame">トラブルシューティング</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="ref-trouble" aria-label="トラブルシューティングランブック確認済み"></label>
      </li>
      <li class="wp-ref" data-page="reference/quick-reference-card.ja.html">
        <span class="wp-ref__body">
          <span class="wp-ref__use">コマンドと値の確認</span>
          <a class="wp-ref__link" href="reference/quick-reference-card.ja.html" target="workshop-content-frame">クイックリファレンス</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="ref-quickref" aria-label="クイックリファレンス確認済み"></label>
      </li>
      <li class="wp-ref" data-page="reference/identity-and-access-guide.ja.html">
        <span class="wp-ref__body">
          <span class="wp-ref__use">認証と権限の背景</span>
          <a class="wp-ref__link" href="reference/identity-and-access-guide.ja.html" target="workshop-content-frame">Identity / Access</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="ref-identity" aria-label="アイデンティティガイド確認済み"></label>
      </li>
      <li class="wp-ref" data-page="reference/bicep-techniques-guide.ja.html">
        <span class="wp-ref__body">
          <span class="wp-ref__use">Bicep の深掘り</span>
          <a class="wp-ref__link" href="reference/bicep-techniques-guide.ja.html" target="workshop-content-frame">Bicep テクニック</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="ref-bicep" aria-label="Bicep テクニックガイド確認済み"></label>
      </li>
      <li class="wp-ref" data-page="development/local-development-guide.ja.html">
        <span class="wp-ref__body">
          <span class="wp-ref__use">ローカル開発</span>
          <a class="wp-ref__link" href="development/local-development-guide.ja.html" target="workshop-content-frame">ローカル開発ガイド</a>
        </span>
        <label class="wp-check"><input type="checkbox" data-progress-id="ref-localdev" aria-label="ローカル開発ガイド確認済み"></label>
      </li>
    </ul>
  </nav>

  <section class="workshop-content" aria-label="選択した教材本文">
    <iframe
      name="workshop-content-frame"
      src="learner/learner-quickstart.ja.html"
      title="選択したワークショップ教材本文"></iframe>
  </section>
</div>

<script>
  (function () {
    'use strict';

    var STORAGE_KEY = 'aiw-portal-progress-v1';
    var portal = document.querySelector('.workshop-portal');
    if (!portal) {
      return;
    }

    var frame = portal.querySelector('iframe[name="workshop-content-frame"]');
    var checkboxes = Array.prototype.slice.call(portal.querySelectorAll('input[type="checkbox"][data-progress-id]'));
    var stepItems = Array.prototype.slice.call(portal.querySelectorAll('.wp-step'));
    var navItems = Array.prototype.slice.call(portal.querySelectorAll('[data-page]'));
    var countEl = portal.querySelector('[data-progress-count]');
    var totalEl = portal.querySelector('[data-progress-total]');
    var fillEl = portal.querySelector('[data-progress-fill]');
    var barEl = portal.querySelector('[role="progressbar"]');
    var resetBtn = portal.querySelector('[data-progress-reset]');

    function readState() {
      try {
        return JSON.parse(localStorage.getItem(STORAGE_KEY)) || {};
      } catch (err) {
        return {};
      }
    }

    function writeState(state) {
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
      } catch (err) {
        /* storage unavailable (private mode): progress is session-only */
      }
    }

    function updateProgress() {
      var done = 0;
      stepItems.forEach(function (li) {
        var box = li.querySelector('input[type="checkbox"]');
        var isDone = !!(box && box.checked);
        li.classList.toggle('is-done', isDone);
        if (isDone) {
          done += 1;
        }
      });

      var total = stepItems.length;
      var pct = total ? Math.round((done / total) * 100) : 0;
      if (countEl) { countEl.textContent = String(done); }
      if (totalEl) { totalEl.textContent = String(total); }
      if (fillEl) { fillEl.style.width = pct + '%'; }
      if (barEl) {
        barEl.setAttribute('aria-valuemax', String(total));
        barEl.setAttribute('aria-valuenow', String(done));
      }
    }

    var state = readState();
    checkboxes.forEach(function (box) {
      var id = box.getAttribute('data-progress-id');
      if (state[id]) {
        box.checked = true;
      }
      box.addEventListener('change', function () {
        var next = readState();
        if (box.checked) {
          next[id] = true;
        } else {
          delete next[id];
        }
        writeState(next);
        updateProgress();
      });
    });
    updateProgress();

    if (resetBtn) {
      resetBtn.addEventListener('click', function () {
        writeState({});
        checkboxes.forEach(function (box) { box.checked = false; });
        updateProgress();
      });
    }

    function setActive(pagePath) {
      if (!pagePath) {
        return;
      }
      navItems.forEach(function (li) {
        var target = li.getAttribute('data-page');
        li.classList.toggle('is-active', !!target && pagePath.indexOf(target) !== -1);
      });
    }

    if (frame) {
      setActive(frame.getAttribute('src'));
    }

    navItems.forEach(function (li) {
      var link = li.querySelector('a');
      if (!link) {
        return;
      }
      link.addEventListener('click', function () {
        setActive(link.getAttribute('href'));
      });
    });

    var EMBEDDED_STYLE = [
      '.site-header,.site-footer{display:none !important;}',
      '.page-content{padding:1.4rem 0 2rem;}',
      '.page-content>.wrapper{max-width:900px;}',
      'body{color:#1b2430;line-height:1.75;}',
      'h1{font-size:1.9rem;line-height:1.25;}',
      'h2{margin-top:2.1rem;padding-bottom:.35rem;border-bottom:2px solid #e3e8ef;}',
      'h3{margin-top:1.5rem;}',
      'a{color:#0067c0;}',
      'table{border-collapse:collapse;width:100%;margin:1rem 0;font-size:.95rem;}',
      'th,td{border:1px solid #e3e8ef;padding:.55rem .7rem;text-align:left;vertical-align:top;}',
      'thead th{background:#eef3f9;color:#1b2430;}',
      'tbody tr:nth-child(even){background:#f7f9fc;}',
      'pre{background:#0b1f33;color:#e6edf3;border-radius:10px;padding:1rem 1.1rem;overflow:auto;line-height:1.6;}',
      'code{background:#eef2f7;color:#0b3a66;padding:.12rem .4rem;border-radius:5px;font-size:.92em;}',
      'pre code{background:transparent;color:inherit;padding:0;}',
      'blockquote{margin:1rem 0;padding:.6rem 1rem;border-left:4px solid #0078d4;background:#f1f7fd;color:#33414f;border-radius:0 8px 8px 0;}',
      'ul,ol{padding-left:1.3rem;}',
      'li{margin:.2rem 0;}',
      'img{max-width:100%;height:auto;}',
      'hr{border:0;border-top:1px solid #e3e8ef;margin:1.8rem 0;}'
    ].join('');

    if (frame) {
      frame.addEventListener('load', function () {
        try {
          var loaded = frame.contentWindow.location.pathname;
          if (loaded) {
            setActive(loaded);
          }
        } catch (err) {
          /* cross-origin: keep click-based active state */
        }

        var doc = frame.contentDocument;
        if (!doc || doc.getElementById('embedded-workshop-style')) {
          return;
        }
        var style = doc.createElement('style');
        style.id = 'embedded-workshop-style';
        style.textContent = EMBEDDED_STYLE;
        doc.head.appendChild(style);
      });
    }
  })();
</script>

## 現在の整備状況

Day 0、Day 1、Day 2、トラブルシューティング、クイックリファレンスの主要導線を整備しています。クリーンアップ専用ページと英語版同期は後続フェーズで拡張します。
