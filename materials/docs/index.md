---
title: Azure IaaS Workshop 受講者ポータル
---

# Azure IaaS Workshop 受講者ポータル

このポータルは、2 日版 Azure IaaS Workshop を進めるための受講者向け入口です。CLI とスクリプト作業は **Azure Cloud Shell (Bash)** を標準にし、ローカル PC にはブラウザ以外のツールを原則として要求しません。

<style>
  .page-content > .wrapper {
    max-width: 1320px;
  }

  .workshop-portal {
    display: grid;
    gap: 1rem;
    grid-template-columns: minmax(22rem, 32%) minmax(0, 1fr);
    margin-top: 1.5rem;
  }

  .workshop-toc {
    border: 1px solid #d0d7de;
    border-radius: 0.5rem;
    max-height: 82vh;
    overflow: auto;
    padding: 1rem;
    position: sticky;
    top: 1rem;
  }

  .workshop-toc h2 {
    font-size: 1.15rem;
    margin-top: 0;
  }

  .workshop-toc table {
    font-size: 0.9rem;
    margin-bottom: 1.5rem;
  }

  .workshop-toc th,
  .workshop-toc td {
    padding: 0.35rem 0.45rem;
    vertical-align: top;
  }

  .workshop-toc input[type="checkbox"] {
    transform: scale(1.2);
  }

  .workshop-content {
    border: 1px solid #d0d7de;
    border-radius: 0.5rem;
    min-height: 82vh;
    overflow: hidden;
  }

  .workshop-content iframe {
    border: 0;
    display: block;
    height: 82vh;
    width: 100%;
  }

  @media (max-width: 900px) {
    .workshop-portal {
      grid-template-columns: 1fr;
    }

    .workshop-toc {
      max-height: none;
      position: static;
    }

    .workshop-content iframe {
      height: 75vh;
    }
  }
</style>

<div class="workshop-portal">
  <nav class="workshop-toc" aria-label="ワークショップ教材 TOC">
    <h2>ワークショップ進行 TOC</h2>
    <p>左の表を上から順に進めます。右端のチェックボックスは、受講者が自分の進捗確認に使うための一時的なチェック欄です。</p>

    <table>
      <thead>
        <tr>
          <th>順番</th>
          <th>タイミング</th>
          <th>ページ</th>
          <th>完了</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>1</td>
          <td>事前確認</td>
          <td><a href="learner/learner-quickstart.ja.html" target="workshop-content-frame">受講者クイックスタート</a></td>
          <td><input type="checkbox" aria-label="受講者クイックスタート完了"></td>
        </tr>
        <tr>
          <td>2</td>
          <td>Day 0</td>
          <td><a href="learner/day-0-prerequisites.ja.html" target="workshop-content-frame">Day 0: 事前準備</a></td>
          <td><input type="checkbox" aria-label="Day 0 事前準備完了"></td>
        </tr>
        <tr>
          <td>3</td>
          <td>Day 1 開始</td>
          <td><a href="learner/azure-cloud-shell-guide.ja.html" target="workshop-content-frame">Azure Cloud Shell ガイド</a></td>
          <td><input type="checkbox" aria-label="Azure Cloud Shell ガイド完了"></td>
        </tr>
        <tr>
          <td>4</td>
          <td>Day 1 本編</td>
          <td><a href="learner/day-1-deployment-checklist.ja.html" target="workshop-content-frame">Day 1: デプロイチェックリスト</a></td>
          <td><input type="checkbox" aria-label="Day 1 デプロイチェックリスト完了"></td>
        </tr>
        <tr>
          <td>5</td>
          <td>Day 1 監視</td>
          <td><a href="operations/monitoring-guide.ja.html" target="workshop-content-frame">監視ガイド</a></td>
          <td><input type="checkbox" aria-label="監視ガイド完了"></td>
        </tr>
        <tr>
          <td>6</td>
          <td>Day 2 本編</td>
          <td><a href="learner/day-2-resiliency-checklist.ja.html" target="workshop-content-frame">Day 2: 回復性チェックリスト</a></td>
          <td><input type="checkbox" aria-label="Day 2 回復性チェックリスト完了"></td>
        </tr>
        <tr>
          <td>7</td>
          <td>Day 2 補足</td>
          <td><a href="operations/disaster-recovery-guide.ja.html" target="workshop-content-frame">災害復旧ガイド</a></td>
          <td><input type="checkbox" aria-label="災害復旧ガイド完了"></td>
        </tr>
      </tbody>
    </table>

    <h2>迷ったときの参照 TOC</h2>
    <table>
      <thead>
        <tr>
          <th>用途</th>
          <th>ページ</th>
          <th>確認</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td>症状別の切り分け</td>
          <td><a href="operations/troubleshooting-runbook.ja.html" target="workshop-content-frame">トラブルシューティング</a></td>
          <td><input type="checkbox" aria-label="トラブルシューティングランブック確認済み"></td>
        </tr>
        <tr>
          <td>コマンドと値の確認</td>
          <td><a href="reference/quick-reference-card.ja.html" target="workshop-content-frame">クイックリファレンス</a></td>
          <td><input type="checkbox" aria-label="クイックリファレンス確認済み"></td>
        </tr>
        <tr>
          <td>認証と権限の背景</td>
          <td><a href="reference/identity-and-access-guide.ja.html" target="workshop-content-frame">Identity / Access</a></td>
          <td><input type="checkbox" aria-label="アイデンティティガイド確認済み"></td>
        </tr>
        <tr>
          <td>Bicep の深掘り</td>
          <td><a href="reference/bicep-techniques-guide.ja.html" target="workshop-content-frame">Bicep テクニック</a></td>
          <td><input type="checkbox" aria-label="Bicep テクニックガイド確認済み"></td>
        </tr>
        <tr>
          <td>ローカル開発</td>
          <td><a href="development/local-development-guide.ja.html" target="workshop-content-frame">ローカル開発ガイド</a></td>
          <td><input type="checkbox" aria-label="ローカル開発ガイド確認済み"></td>
        </tr>
      </tbody>
    </table>
  </nav>

  <section class="workshop-content" aria-label="選択した教材本文">
    <iframe
      name="workshop-content-frame"
      src="learner/learner-quickstart.ja.html"
      title="選択したワークショップ教材本文"></iframe>
  </section>
</div>

<script>
  document.addEventListener('DOMContentLoaded', () => {
    const contentFrame = document.querySelector('iframe[name="workshop-content-frame"]');
    if (!contentFrame) {
      return;
    }

    contentFrame.addEventListener('load', () => {
      const frameDocument = contentFrame.contentDocument;
      if (!frameDocument || frameDocument.getElementById('embedded-workshop-style')) {
        return;
      }

      const style = frameDocument.createElement('style');
      style.id = 'embedded-workshop-style';
      style.textContent = `
        .site-header,
        .site-footer {
          display: none;
        }

        .page-content {
          padding: 1.5rem 0;
        }

        .page-content > .wrapper {
          max-width: 920px;
        }
      `;
      frameDocument.head.appendChild(style);
    });
  });
</script>

## 現在の整備状況

Day 0、Day 1、Day 2、トラブルシューティング、クイックリファレンスの主要導線を整備しています。クリーンアップ専用ページと英語版同期は後続フェーズで拡張します。

## GitHub Pages を有効化する場合

このリポジトリでは GitHub Actions-based Pages を使います。リポジトリの **Settings > Pages** で source を **GitHub Actions** に設定すると、このポータルが公開されます。公開 URL は通常 `https://<OWNER>.github.io/<REPOSITORY>/` です。
