import { parseArgs, runDailyBrief, runIngest, runPurgeSeed, runPurgeNonTech, JobDeps } from '../src/jobs';
import { DAILY_BRIEF_TOPIC } from '../src/notifications/push-service';

const brief = {
  id: 'brief-2026-11-01',
  date: {} as any,
  title: 'Today in Tech',
  subtitle: '',
  items: [
    {
      rank: 1,
      articleId: 'a1',
      headline: 'Big launch',
      whyItMatters: 'x',
      category: 'ai',
      sourceName: 'S',
      sourceUrl: 'https://s.example/a1',
    },
  ],
  createdAt: {} as any,
};

function pushMock() {
  return { sendToTopic: jest.fn().mockResolvedValue('msg-1') };
}

describe('jobs CLI (GitHub Actions runner)', () => {
  test('purge-non-tech is a dry run unless --apply', () => {
    expect(parseArgs(['purge-non-tech']).apply).toBe(false);
    expect(parseArgs(['purge-non-tech', '--apply']).apply).toBe(true);
    expect(parseArgs(['purge-non-tech', '--apply', '--dry-run']).apply).toBe(false);
  });

  test('runPurgeNonTech lists matches without deleting by default, deletes with --apply', async () => {
    const docs = [
      { id: 'a', data: () => ({ slug: 'a', headline: 'BJP wins assembly polls in three states', category: 'startups-india', publishedAt: new Date().toISOString(), updatedAt: new Date().toISOString(), sources: [{ name: 'ET', url: 'https://economictimes.indiatimes.com/a.cms', title: 'BJP sweeps assembly polls', publishedAt: new Date().toISOString() }], whatHappened: 'The party won the election.' }) },
      { id: 'b', data: () => ({ slug: 'b', headline: 'Jio adds more 5G data to prepaid plans', category: 'telecom', publishedAt: new Date().toISOString(), updatedAt: new Date().toISOString(), sources: [{ name: 'ET', url: 'https://economictimes.indiatimes.com/b.cms', title: 'Jio 5G plans', publishedAt: new Date().toISOString() }], whatHappened: 'More data.' }) },
    ];
    const deletes: string[] = [];
    const sets: string[] = [];
    const db: any = {
      collection: (name: string) => ({
        get: async () => ({ docs, size: docs.length }),
        doc: (id: string) => ({ path: `${name}/${id}` }),
      }),
      batch: () => ({ delete: (ref: any) => deletes.push(ref.path), set: (ref: any) => sets.push(ref.path), commit: async () => undefined }),
    };
    const dry = await runPurgeNonTech(parseArgs(['purge-non-tech']), { db });
    expect(dry.dryRun).toBe(true);
    expect(dry.matched.map((m) => m.id)).toEqual(['a']);
    expect(deletes).toHaveLength(0);
    const real = await runPurgeNonTech(parseArgs(['purge-non-tech', '--apply']), { db });
    expect(real.deleted).toBe(1);
    expect(deletes).toEqual(['stories/a', 'storySources/a']);
    expect(sets.some((p) => p.startsWith('storyBriefs/'))).toBe(true);
  });

  test('parseArgs reads command and flags', () => {
    expect(parseArgs(['ingest', '--dry-run', '--concurrency=5', '--source=verge'])).toMatchObject({
      command: 'ingest',
      dryRun: true,
      push: true,
      source: 'verge',
      concurrency: 5,
      jsonOut: undefined,
      out: '../build/web',
    });
    expect(parseArgs(['render', '--out=/tmp/w', '--from-json=s.json', '--cache=.cache/s.json'])).toMatchObject({
      command: 'render',
      out: '/tmp/w',
      fromJson: 's.json',
      cache: '.cache/s.json',
    });
    expect(parseArgs(['migrate-articles', '--limit=50']).limit).toBe(50);
    expect(parseArgs(['ingest']).concurrency).toBe(6);
    expect(parseArgs(['daily-brief', '--no-push']).push).toBe(false);
    expect(parseArgs(['purge-seed']).dryRun).toBe(false);
    expect(() => parseArgs(['--dry-run'])).toThrow(/command/);
    expect(() => parseArgs(['deploy'])).toThrow(/Unknown/);
  });

  test('daily-brief generates and pushes to the daily-brief topic', async () => {
    const push = pushMock();
    const deps: JobDeps = { push, briefGenerator: { generateDailyBrief: jest.fn().mockResolvedValue(brief) } };
    const out = await runDailyBrief(parseArgs(['daily-brief']), deps);
    expect(out.pushId).toBe('msg-1');
    expect(push.sendToTopic).toHaveBeenCalledWith(
      DAILY_BRIEF_TOPIC,
      expect.objectContaining({ title: 'Today in Tech', body: 'Big launch', data: expect.objectContaining({ briefId: brief.id }) })
    );
  });

  test('daily-brief --no-push and empty brief send nothing', async () => {
    const push = pushMock();
    await runDailyBrief(parseArgs(['daily-brief', '--no-push']), {
      push,
      briefGenerator: { generateDailyBrief: jest.fn().mockResolvedValue(brief) },
    });
    await runDailyBrief(parseArgs(['daily-brief']), {
      push,
      briefGenerator: { generateDailyBrief: jest.fn().mockResolvedValue(null) },
    });
    expect(push.sendToTopic).not.toHaveBeenCalled();
  });

  test('purge-seed dry run never regenerates the brief', async () => {
    const gen = { generateDailyBrief: jest.fn() };
    const svc = { purgeSeedArticles: jest.fn().mockResolvedValue({ scanned: 10, matched: 3, deleted: 0, dryRun: true, sample: [] }) };
    const out = await runPurgeSeed(parseArgs(['purge-seed', '--dry-run']), { push: pushMock(), adminService: svc, briefGenerator: gen });
    expect(svc.purgeSeedArticles).toHaveBeenCalledWith(true);
    expect(gen.generateDailyBrief).not.toHaveBeenCalled();
    expect(out.briefRegenerated).toBe(false);
  });

  test('purge-seed live regenerates the brief after deletions', async () => {
    const gen = { generateDailyBrief: jest.fn().mockResolvedValue(brief) };
    const svc = { purgeSeedArticles: jest.fn().mockResolvedValue({ scanned: 10, matched: 3, deleted: 3, dryRun: false, sample: [] }) };
    const out = await runPurgeSeed(parseArgs(['purge-seed']), { push: pushMock(), adminService: svc, briefGenerator: gen });
    expect(svc.purgeSeedArticles).toHaveBeenCalledWith(false);
    expect(out.briefRegenerated).toBe(true);
  });

  test('ingest fails only when every source failed', async () => {
    const mk = (statuses: ('success' | 'failed')[]) => ({
      runAll: jest.fn().mockResolvedValue({
        startedAt: '',
        completedAt: '',
        sourcesProcessed: statuses.length,
        totalArticlesFound: 0,
        totalAccepted: 0,
        totalDuplicates: 0,
        totalRejected: 0,
        totalWithImage: 0,
        sourcesStats: statuses.map((status, i) => ({ sourceId: `s${i}`, status })),
      }),
      processSource: jest.fn(),
    });
    const args = parseArgs(['ingest']);
    expect((await runIngest(args, { push: pushMock(), engine: mk(['failed', 'success']) as any })).ok).toBe(true);
    expect((await runIngest(args, { push: pushMock(), engine: mk(['failed', 'failed']) as any })).ok).toBe(false);
  });
});
