// HostBlock download-redirect Worker.
//
// GET hostblock.app/download -> 302 to the current DMG, read from the latest.json
// update feed (FEED_URL) so it always tracks the latest release.

export default {
  async fetch(request, env) {
    if (request.method !== 'GET' && request.method !== 'HEAD') {
      return new Response('Method Not Allowed', { status: 405 });
    }

    try {
      const res = await fetch(env.FEED_URL);
      if (!res.ok) throw new Error(`feed ${res.status}`);

      const { url } = await res.json();

      return Response.redirect(url, 302); // 302 since target changes each release
    } catch {
      return new Response('Download temporarily unavailable.', { status: 502 });
    }
  },
};
