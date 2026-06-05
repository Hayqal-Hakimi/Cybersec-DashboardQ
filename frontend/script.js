/**
 * Core Engine — Frontend Logic
 * Handles API calls, tab switching, and UI updates.
 */

// ============================================
// DOM References
// ============================================
const DOM = {
  // Input
  inputText: document.getElementById('input-text'),
  inputHeaders: document.getElementById('input-headers'),
  inputFileHash: document.getElementById('input-file-hash'),
  modelSelect: document.getElementById('model-select'),

  // Tabs
  tabBtns: document.querySelectorAll('.tab-btn'),
  tabContents: document.querySelectorAll('.tab-content'),

  // Buttons
  btnAnalyze: document.getElementById('btn-analyze'),
  btnClear: document.getElementById('btn-clear-input'),
  btnCloudWatch: document.getElementById('btn-cloudwatch'),
  btnViewLogs: document.getElementById('btn-view-logs'),
  btnUpgrade: document.getElementById('btn-upgrade-node'),

  // Nav
  navLogs: document.getElementById('nav-logs'),
  navSettings: document.getElementById('nav-settings'),
  navHelp: document.getElementById('nav-help'),
  navSignOut: document.getElementById('nav-signout'),
  navThreatMonitor: document.getElementById('nav-threat-monitor'),
  navHeuristics: document.getElementById('nav-heuristics'),
  navAiScan: document.getElementById('nav-ai-scan'),

  // Views & Content
  viewMain: document.getElementById('view-main'),
  viewLogs: document.getElementById('view-logs'),
  viewHeuristics: document.getElementById('view-heuristics'),
  logsTableBody: document.getElementById('logs-table-body'),
  statTotalScans: document.getElementById('stat-total-scans'),
  statScams: document.getElementById('stat-scams'),
  statAvgTime: document.getElementById('stat-avg-time'),
  statSafe: document.getElementById('stat-safe'),

  // Top bar
  btnNotifications: document.getElementById('btn-notifications'),
  btnTopSettings: document.getElementById('btn-top-settings'),
  searchInput: document.getElementById('search-input'),

  // Threat Analysis Panel
  threatScoreCard: document.getElementById('threat-score-card'),
  threatPercentage: document.getElementById('threat-percentage'),
  threatLabel: document.getElementById('threat-label'),
  threatIcon: document.getElementById('threat-icon'),
  toggleAnalysis: document.getElementById('toggle-analysis'),

  // Risk Bars
  riskMetadataLevel: document.getElementById('risk-metadata-level'),
  riskMetadataBar: document.getElementById('risk-metadata-bar'),
  riskPhishingLevel: document.getElementById('risk-phishing-level'),
  riskPhishingBar: document.getElementById('risk-phishing-bar'),
  riskToneLevel: document.getElementById('risk-tone-level'),
  riskToneBar: document.getElementById('risk-tone-bar'),

  // Inference
  inferenceTimeText: document.getElementById('inference-time-text'),

  // Loading
  loadingOverlay: document.getElementById('loading-overlay'),
};

// ============================================
// State
// ============================================
let currentTab = 'raw-text';
let lastResult = null;
let localLogsArray = [];

const API_URL = 'http://127.0.0.1:8000';

// ============================================
// Tab Switching
// ============================================
DOM.tabBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    const tabId = btn.dataset.tab;
    if (tabId === currentTab) return;

    // Update tab buttons
    DOM.tabBtns.forEach(b => b.classList.remove('active'));
    btn.classList.add('active');

    // Update tab content
    DOM.tabContents.forEach(c => c.classList.remove('active'));
    const targetContent = document.getElementById(`content-${tabId}`);
    if (targetContent) {
      targetContent.classList.add('active');
    }

    currentTab = tabId;
  });
});

// ============================================
// Get Active Input Text
// ============================================
function getActiveInput() {
  switch (currentTab) {
    case 'raw-text':
      return DOM.inputText.value.trim();
    case 'headers':
      return DOM.inputHeaders.value.trim();
    case 'file-hash':
      return DOM.inputFileHash.value.trim();
    default:
      return DOM.inputText.value.trim();
  }
}

// ============================================
// Clear Input
// ============================================
DOM.btnClear.addEventListener('click', () => {
  DOM.inputText.value = '';
  DOM.inputHeaders.value = '';
  DOM.inputFileHash.value = '';
  resetThreatPanel();
  console.log('[Core Engine] Input cleared.');
});

// ============================================
// Analyze Threat
// ============================================
DOM.btnAnalyze.addEventListener('click', async () => {
  const text = getActiveInput();

  if (!text) {
    shakeButton(DOM.btnAnalyze);
    console.log('[Core Engine] No input provided.');
    return;
  }

  const model = DOM.modelSelect.value;

  // Show loading state
  setLoading(true);

  try {
    const startTime = performance.now();

    const response = await fetch(`${API_URL}/analyze`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text, model }),
    });

    if (!response.ok) {
      throw new Error(`Server error: ${response.status}`);
    }

    const data = await response.json();
    const clientLatency = Math.round(performance.now() - startTime);

    lastResult = data;
    updateThreatPanel(data, clientLatency);

    // Save to local logs
    localLogsArray.push({
      timestamp: new Date(data.timestamp).toLocaleString(),
      model: model,
      inputPreview: text.substring(0, 50) + (text.length > 50 ? '...' : ''),
      score: data.threat_score,
      status: data.threat_type,
      inferenceTime: data.inference_time_ms
    });

    console.log('[Core Engine] Analysis result:', JSON.stringify(data, null, 2));

  } catch (error) {
    console.error('[Core Engine] Request failed:', error.message);
    showError(error.message);
  } finally {
    setLoading(false);
  }
});

// ============================================
// Update Threat Analysis Panel
// ============================================
function updateThreatPanel(data, clientLatency) {
  const isThreat = data.threat_score >= 50;

  // Update score card class
  DOM.threatScoreCard.classList.remove('threat-active', 'safe-active');
  DOM.threatScoreCard.classList.add(isThreat ? 'threat-active' : 'safe-active');

  // Animate percentage
  animateCounter(DOM.threatPercentage, data.threat_score, '%');

  // Update label
  DOM.threatLabel.textContent = isThreat
    ? `THREAT DETECTED: ${data.threat_type}`
    : `STATUS: ${data.threat_type}`;

  // Update risk breakdown bars with animation
  const breakdown = data.risk_breakdown;

  updateRiskBar(
    DOM.riskMetadataLevel,
    DOM.riskMetadataBar,
    breakdown.metadata_spoofing.level,
    breakdown.metadata_spoofing.value
  );

  updateRiskBar(
    DOM.riskPhishingLevel,
    DOM.riskPhishingBar,
    breakdown.phishing_links.level,
    breakdown.phishing_links.value
  );

  updateRiskBar(
    DOM.riskToneLevel,
    DOM.riskToneBar,
    breakdown.suspicious_tone.level,
    breakdown.suspicious_tone.value
  );

  // Update inference time — use server-reported time
  DOM.inferenceTimeText.textContent = `Inference: ${data.inference_time_ms}ms (RTT: ${clientLatency}ms)`;
}

// ============================================
// Risk Bar Update
// ============================================
function updateRiskBar(levelEl, barEl, level, value) {
  // Set level text
  levelEl.textContent = level;

  // Remove old level classes
  levelEl.className = 'risk-level';

  // Map level to CSS class
  const levelMap = {
    'Critical': 'level-critical',
    'High': 'level-high',
    'Elevated': 'level-elevated',
    'Low': 'level-low',
    'Minimal': 'level-minimal',
  };

  const cls = levelMap[level];
  if (cls) {
    levelEl.classList.add(cls);
  }

  // Color the bar based on level
  const colorMap = {
    'Critical': 'var(--threat-critical)',
    'High': 'var(--threat-high)',
    'Elevated': 'var(--threat-elevated)',
    'Low': 'var(--threat-low)',
    'Minimal': 'var(--threat-minimal)',
  };

  barEl.style.background = colorMap[level] || 'var(--accent-coral)';

  // Animate width
  requestAnimationFrame(() => {
    barEl.style.width = `${value}%`;
  });
}

// ============================================
// Animate Counter
// ============================================
function animateCounter(el, target, suffix = '') {
  const duration = 600;
  const start = performance.now();
  const from = 0;

  el.classList.add('animate-score');

  function update(now) {
    const elapsed = now - start;
    const progress = Math.min(elapsed / duration, 1);

    // Ease out cubic
    const eased = 1 - Math.pow(1 - progress, 3);
    const current = Math.round(from + (target - from) * eased);

    el.textContent = `${current}${suffix}`;

    if (progress < 1) {
      requestAnimationFrame(update);
    } else {
      el.classList.remove('animate-score');
    }
  }

  requestAnimationFrame(update);
}

// ============================================
// Reset Panel
// ============================================
function resetThreatPanel() {
  DOM.threatScoreCard.classList.remove('threat-active', 'safe-active');
  DOM.threatPercentage.textContent = '—';
  DOM.threatLabel.textContent = 'AWAITING INPUT';
  DOM.riskMetadataLevel.textContent = '—';
  DOM.riskMetadataLevel.className = 'risk-level';
  DOM.riskMetadataBar.style.width = '0%';
  DOM.riskPhishingLevel.textContent = '—';
  DOM.riskPhishingLevel.className = 'risk-level';
  DOM.riskPhishingBar.style.width = '0%';
  DOM.riskToneLevel.textContent = '—';
  DOM.riskToneLevel.className = 'risk-level';
  DOM.riskToneBar.style.width = '0%';
  DOM.inferenceTimeText.textContent = 'Inference: —';
  lastResult = null;
}

// ============================================
// Loading State
// ============================================
function setLoading(active) {
  if (active) {
    DOM.btnAnalyze.classList.add('loading');
    DOM.loadingOverlay.classList.add('active');
  } else {
    DOM.btnAnalyze.classList.remove('loading');
    DOM.loadingOverlay.classList.remove('active');
  }
}

// ============================================
// Error Display
// ============================================
function showError(message) {
  DOM.threatScoreCard.classList.remove('threat-active', 'safe-active');
  DOM.threatPercentage.textContent = '!';
  DOM.threatLabel.textContent = `ERROR: ${message}`;
  DOM.threatLabel.style.fontSize = '0.65rem';

  setTimeout(() => {
    DOM.threatLabel.style.fontSize = '';
  }, 5000);
}

// ============================================
// Shake Animation (for empty input)
// ============================================
function shakeButton(btn) {
  btn.style.animation = 'none';
  btn.offsetHeight; // trigger reflow
  btn.style.animation = 'shake 0.4s ease';
  setTimeout(() => { btn.style.animation = ''; }, 400);
}

// Add shake keyframes dynamically
const shakeStyle = document.createElement('style');
shakeStyle.textContent = `
  @keyframes shake {
    0%, 100% { transform: translateX(0); }
    20% { transform: translateX(-8px); }
    40% { transform: translateX(8px); }
    60% { transform: translateX(-4px); }
    80% { transform: translateX(4px); }
  }
`;
document.head.appendChild(shakeStyle);

// ============================================
// Placeholder Buttons — console.log / alert
// ============================================

// Ship to CloudWatch
DOM.btnCloudWatch.addEventListener('click', () => {
  if (!lastResult) {
    console.log('[Core Engine] No analysis result to ship.');
    alert('⚠️ No analysis result available. Run an analysis first.');
    return;
  }
  console.log('[Core Engine] Shipping to CloudWatch:', JSON.stringify(lastResult, null, 2));
  alert('✅ Analysis result shipped to CloudWatch!\n\n(Check console for payload)');
});

// View Detailed Logs JSON
DOM.btnViewLogs.addEventListener('click', (e) => {
  e.preventDefault();
  if (!lastResult) {
    console.log('[Core Engine] No logs available.');
    alert('⚠️ No logs available. Run an analysis first.');
    return;
  }
  console.log('[Core Engine] Detailed Logs JSON:', JSON.stringify(lastResult, null, 2));
  alert('📋 Logs printed to console.\n\n' + JSON.stringify(lastResult, null, 2));
});

// ============================================
// SPA View Switching
// ============================================
function switchView(viewId) {
  // Reset all nav items
  document.querySelectorAll('.sidebar-nav .nav-item').forEach(item => {
    item.classList.remove('active');
  });

  // Hide all views
  DOM.viewMain.classList.remove('active');
  DOM.viewLogs.classList.remove('active');
  DOM.viewHeuristics.classList.remove('active');

  // Show target view
  if (viewId === 'main') {
    DOM.viewMain.classList.add('active');
  } else if (viewId === 'logs') {
    DOM.viewLogs.classList.add('active');
    DOM.navLogs.classList.add('active');
    renderLogsTable();
  } else if (viewId === 'heuristics') {
    DOM.viewHeuristics.classList.add('active');
    DOM.navHeuristics.classList.add('active');
    renderHeuristics();
  }
}

// ============================================
// Render Logs & Heuristics
// ============================================
function renderLogsTable() {
  if (localLogsArray.length === 0) {
    DOM.logsTableBody.innerHTML = '<tr><td colspan="5" style="text-align: center; padding: 32px; color: var(--text-muted);">No logs available yet. Run an analysis.</td></tr>';
    return;
  }
  
  // Render array (newest first)
  const reversed = [...localLogsArray].reverse();
  DOM.logsTableBody.innerHTML = reversed.map(log => `
    <tr>
      <td style="font-family: var(--font-mono); font-size: 0.8rem;">${log.timestamp}</td>
      <td>${log.model}</td>
      <td style="font-family: var(--font-mono); font-size: 0.8rem; opacity: 0.8;">${log.inputPreview.replace(/</g, '&lt;')}</td>
      <td style="font-family: var(--font-mono);">${log.score}%</td>
      <td class="${log.status === 'SCAM' ? 'status-scam' : 'status-safe'}">${log.status}</td>
    </tr>
  `).join('');
}

function renderHeuristics() {
  const total = localLogsArray.length;
  if (total === 0) {
    DOM.statTotalScans.textContent = '0';
    DOM.statScams.textContent = '0';
    DOM.statSafe.textContent = '0';
    DOM.statAvgTime.textContent = '0 ms';
    return;
  }

  const scams = localLogsArray.filter(l => l.status === 'SCAM').length;
  const safe = localLogsArray.filter(l => l.status === 'SAFE').length;
  const avgTime = Math.round(localLogsArray.reduce((acc, l) => acc + l.inferenceTime, 0) / total);

  DOM.statTotalScans.textContent = total;
  DOM.statScams.textContent = scams;
  DOM.statSafe.textContent = safe;
  DOM.statAvgTime.textContent = `${avgTime} ms`;
}

// ============================================
// Placeholder Buttons & Nav
// ============================================

// Logs sidebar
DOM.navLogs.addEventListener('click', (e) => {
  e.preventDefault();
  switchView('logs');
});

// Heuristics
DOM.navHeuristics.addEventListener('click', (e) => {
  e.preventDefault();
  switchView('heuristics');
});

// Threat Monitor
DOM.navThreatMonitor.addEventListener('click', (e) => {
  e.preventDefault();
  switchView('main');
  DOM.navThreatMonitor.classList.add('active');
});

// AI Scan
DOM.navAiScan.addEventListener('click', (e) => {
  e.preventDefault();
  switchView('main');
  DOM.navAiScan.classList.add('active');
});

// Notifications
DOM.btnNotifications.addEventListener('click', () => {
  console.log('[Core Engine] Notifications opened (placeholder).');
  alert('🔔 Notifications — No new alerts');
});

// Top Settings
DOM.btnTopSettings.addEventListener('click', () => {
  console.log('[Core Engine] Top-bar settings opened (placeholder).');
  alert('⚙️ Settings — Coming soon in v4.3.0');
});

// Search
DOM.searchInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') {
    const query = DOM.searchInput.value.trim();
    if (query) {
      console.log(`[Core Engine] Search query: "${query}"`);
      alert(`🔍 Search for: "${query}"\n\nSearch functionality coming soon in v4.3.0`);
    }
  }
});

// Toggle Analysis Panel
DOM.toggleAnalysis.addEventListener('change', () => {
  const panel = document.querySelector('.right-panel');
  const isEnabled = DOM.toggleAnalysis.checked;
  panel.style.opacity = isEnabled ? '1' : '0.4';
  panel.style.pointerEvents = isEnabled ? 'auto' : 'none';
  console.log(`[Core Engine] Threat Analysis panel ${isEnabled ? 'enabled' : 'disabled'}.`);
});

// ============================================
// Keyboard Shortcut: Ctrl+Enter to Analyze
// ============================================
document.addEventListener('keydown', (e) => {
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
    DOM.btnAnalyze.click();
  }
});

// ============================================
// Init Log
// ============================================
console.log(
  '%c[Core Engine v4.2.0] %cSystem initialized. Ready for threat analysis.',
  'color: #00e5ff; font-weight: bold;',
  'color: #94a3b8;'
);
