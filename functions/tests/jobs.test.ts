import { parseArgs, runDailyBrief, runIngest, runPurgeSeed, JobDeps } from '../src/jobs';
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
  test('parseArgs reads command and flags', () => {
    expect(parseArgs(['ingest', '--dry-run', '--concurrency=5', '--source=verge'])).toEqual({
      command: 'ingest',
      dryRun: true,
      push: true,
      source: 'verge',
      concurrency: 5,
      jsonOut: undefined,
    });
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
