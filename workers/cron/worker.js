// TechDaily cron: GitHub's own schedules skip runs, so this Worker dispatches the workflows on time.
// Secret: GH_TOKEN (fine-grained, Actions read/write on purna-ctrl/techdaily only).
const REPO = 'purna-ctrl/techdaily';

export function workflowsFor(cron) {
  if (cron === '30 0 * * *') return ['brief.yml'];
  return ['news.yml'];
}

export async function dispatch(env, workflow, fetchFn = fetch) {
  const res = await fetchFn(`https://api.github.com/repos/${REPO}/actions/workflows/${workflow}/dispatches`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.GH_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'User-Agent': 'techdaily-cron',
      'X-GitHub-Api-Version': '2022-11-28',
    },
    body: JSON.stringify({ ref: 'main' }),
  });
  return res.status;
}

export default {
  async scheduled(event, env, ctx) {
    for (const wf of workflowsFor(event.cron)) {
      const status = await dispatch(env, wf);
      console.log(`dispatch ${wf}: ${status}`);
    }
  },
  async fetch() {
    return new Response('techdaily-cron: ok', { status: 200 });
  },
};
