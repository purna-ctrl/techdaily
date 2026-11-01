import * as admin from 'firebase-admin';
import { IngestionEngine } from './pipeline/ingestion-engine';
import { getSourceById, getAllEnabledSources } from './config/sources';

async function main() {
  const args = process.argv.slice(2);
  const isDryRun = args.includes('--dry-run');
  const sourceArg = args.find((a) => a.startsWith('--source='));
  const specificSourceId = sourceArg ? sourceArg.split('=')[1] : undefined;
  const concArg = args.find((a) => a.startsWith('--concurrency='));
  const concurrency = concArg ? parseInt(concArg.split('=')[1], 10) || 3 : 3;
  const jsonOutArg = args.find((a) => a.startsWith('--json-out='));
  const jsonOut = jsonOutArg ? jsonOutArg.split('=')[1] : undefined;

  console.log('====================================================');
  console.log('  TechDaily News Ingestion Engine (CLI Runner)      ');
  console.log('====================================================');
  console.log(`Mode: ${isDryRun ? 'DRY-RUN (no database writes)' : 'LIVE (Firestore writes enabled)'}`);

  let db: admin.firestore.Firestore | undefined;
  if (!isDryRun) {
    try {
      if (!admin.apps.length) {
        admin.initializeApp();
      }
      db = admin.firestore();
    } catch (e: any) {
      console.warn(`[Notice] Firestore initialization skipped (${e.message}). Defaulting to dry-run mode.`);
    }
  }

  // Dry-run never touches Firestore: no db handle is passed, so no reads/writes/pushes happen.
  const engine = new IngestionEngine(isDryRun ? undefined : db, undefined, undefined, undefined, undefined, {
    sourceConcurrency: concurrency,
  });

  if (specificSourceId) {
    const source = getSourceById(specificSourceId);
    if (!source) {
      console.error(`Error: Source "${specificSourceId}" not found in trusted registry.`);
      process.exit(1);
    }
    console.log(`Processing single source: ${source.sourceName} (${source.domain})`);
    const stats = await engine.processSource(source, isDryRun || !db);
    console.log('\nResult Summary:');
    console.log(JSON.stringify(stats, null, 2));
  } else {
    console.log(`Processing all ${getAllEnabledSources().length} enabled sources...`);
    const summary = await engine.runAll(isDryRun || !db);
    console.log('\nPer-source results:');
    console.table(
      summary.sourcesStats.map((s) => ({
        source: s.sourceId,
        status: s.status,
        found: s.totalFound,
        accepted: s.accepted,
        dup: s.duplicates,
        nearDup: s.nearDuplicates,
        rejected: s.rejected,
        withImage: s.withImage,
        imgFeed: s.imagesFromFeed,
        imgOg: s.imagesFromOgTag,
        error: s.error ?? '',
      }))
    );
    console.log(
      `Totals: found=${summary.totalArticlesFound} accepted=${summary.totalAccepted} withImage=${summary.totalWithImage} duplicates=${summary.totalDuplicates} rejected=${summary.totalRejected}`
    );
    if (jsonOut) {
      const fs = await import('fs');
      fs.writeFileSync(jsonOut, JSON.stringify(summary, null, 2));
      console.log(`Full summary written to ${jsonOut}`);
    }
  }

  console.log('====================================================');
}

main().catch((err) => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});
