// Progress lives only in this browser (localStorage): the set of finished labs.
(function () {
  var KEY = 'tws-local:done';
  function read() { try { return JSON.parse(localStorage.getItem(KEY)) || []; } catch (e) { return []; } }
  window.twsMarkDone = function (id) {
    try { var d = read(); if (d.indexOf(id) < 0) d.push(id); localStorage.setItem(KEY, JSON.stringify(d)); } catch (e) { /* storage blocked */ }
  };
  // Passed tasks per lab, for "3 of 5 tasks" and the "done before" marks. A fresh terminal starts clean each visit,
  // so this records what you have achieved, never state to restore.
  var TKEY = 'tws-local:tasks';
  function readTasks() {
    try { var t = JSON.parse(localStorage.getItem(TKEY)); return t && typeof t === 'object' && !Array.isArray(t) ? t : {}; } catch (e) { return {}; }
  }
  window.twsTasksDone = function (lab) { var l = readTasks()[lab]; return Array.isArray(l) ? l.slice() : []; };
  window.twsMarkTask = function (lab, id) {
    try {
      var t = readTasks(), l = Array.isArray(t[lab]) ? t[lab] : [];
      if (l.indexOf(id) < 0) l.push(id);
      t[lab] = l;
      localStorage.setItem(TKEY, JSON.stringify(t));
    } catch (e) { /* storage blocked */ }
  };
  window.twsTaskSummary = function (lab, total) {
    var n = window.twsTasksDone(lab).length;
    return n > 0 && n < total ? n + ' of ' + total + ' tasks' : '';
  };
  document.querySelectorAll('[data-lab-tasks]').forEach(function (el) {
    var s = window.twsTaskSummary(el.getAttribute('data-lab-tasks'), parseInt(el.getAttribute('data-total'), 10) || 0);
    if (s) el.textContent = ' \u00b7 ' + s;
  });
  // Hints come one tier at a time, and only after the learner has tried: the button appears after a failed Check.
  window.twsHints = function () {
    var fails = {}, asked = {};
    return {
      failed: function (id) { fails[id] = (fails[id] || 0) + 1; },
      ready: function (id, tiers) {
        if (!tiers.length || !fails[id] || (asked[id] || 0) >= tiers.length) return false;
        return { label: asked[id] ? 'Another hint' : 'Need a hint?' };
      },
      next: function (id, tiers) {
        var n = asked[id] || 0;
        if (n >= tiers.length) return null;
        asked[id] = n + 1;
        return (tiers.length > 1 ? 'Hint ' + (n + 1) + ' of ' + tiers.length : 'Hint') + ': ' + tiers[n];
      },
      shown: function (id, tiers) {
        var n = asked[id] || 0;
        if (!n) return '';
        return (tiers.length > 1 ? 'Hint ' + n + ' of ' + tiers.length : 'Hint') + ': ' + tiers[n - 1];
      },
    };
  };
  var done = read();
  document.querySelectorAll('[data-lab]').forEach(function (el) {
    if (done.indexOf(el.getAttribute('data-lab')) >= 0) el.classList.add('is-done');
  });
  // a topic with several labs counts as done once every one of its labs is
  document.querySelectorAll('[data-labs]').forEach(function (el) {
    var keys = el.getAttribute('data-labs').split(',').filter(Boolean);
    if (keys.length && keys.every(function (k) { return done.indexOf(k) >= 0; })) el.classList.add('is-done');
  });
  document.querySelectorAll('[data-track-progress]').forEach(function (el) {
    var t = el.getAttribute('data-track-progress');
    var labs = el.getAttribute('data-labs').split(',').filter(Boolean);
    var n = labs.filter(function (l) { return done.indexOf(t + '/' + l) >= 0; }).length;
    el.textContent = n + ' of ' + labs.length + ' done';
    var card = el.closest('[data-track]');
    if (card) card.style.setProperty('--p', labs.length ? (n / labs.length) : 0);
  });
})();
