const { send } = require('../http');
const pages = require('../pages');

// The public pages: home, videos, roadmap, a track, and a lab's seatless shell.
module.exports = function siteRoutes(router, d) {
  const { cfg, ui, ctxFor, page, getCatalog, getRoadmap, getSite, findLab } = d;

  router.get('/', (req, res) => {
    const home = pages.homeBody(getCatalog(), getRoadmap(), cfg);
    send(res, 200, 'text/html', ui.page(ctxFor('labs'), 'Home', home.body, home.scripts, home.head));
  });
  router.get('/videos', (req, res) => {
    send(res, 200, 'text/html', ui.page(ctxFor('videos'), 'Videos', pages.videosBody(getRoadmap(), getSite()), '', '<script>document.documentElement.classList.add("js")</script><link rel="stylesheet" href="/roadmap.css" />'));
  });
  router.get('/upcoming', (req, res) => { res.writeHead(301, { Location: '/roadmap' }); res.end(); });
  router.get('/roadmap', (req, res) => {
    send(res, 200, 'text/html', ui.page(ctxFor('roadmap'), 'Roadmap', pages.roadmapBody(getRoadmap()),
      '<script src="/roadmap.js"></script><script src="/progress.js"></script>', '<script>document.documentElement.classList.add("js")</script><link rel="stylesheet" href="/roadmap.css" />'));
  });
  router.get(/^\/t\/([a-z0-9-]+)$/, (req, res, { m }) => {
    const track = getCatalog().tracks.find((t) => t.id === m[1]);
    if (!track) return send(res, 404, 'text/html', page('labs', 'Not found', pages.notFoundBody()));
    send(res, 200, 'text/html', page('labs', track.title, pages.trackBody(track, pages.placeOf(getRoadmap(), track.id)), '<script src="/progress.js"></script>'));
  });
  // The page shell takes no seat; the page's JS mints a session with POST /session.
  router.get(/^\/lab\/([a-z0-9-]+)\/([a-z0-9-]+)$/, (req, res, { m }) => {
    const lab = findLab(m[1], m[2]);
    if (!lab) return send(res, 404, 'text/html', page('labs', 'Not found', pages.notFoundBody()));
    const trackTitle = getCatalog().tracks.find((x) => x.id === lab.track).title;
    const { body, scripts } = pages.labBody(lab, trackTitle, cfg, pages.placeOf(getRoadmap(), lab.track), pages.nextLab(getCatalog(), lab.track, lab.id));
    send(res, 200, 'text/html', page('labs', lab.title, body, scripts), { 'Cache-Control': 'no-store' });
  });
};
