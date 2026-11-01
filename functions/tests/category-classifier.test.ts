import { KeywordCategoryClassifier } from '../src/pipeline/category-classifier';

describe('KeywordCategoryClassifier Tests', () => {
  const classifier = new KeywordCategoryClassifier();

  test('classifies AI & Machine Learning stories', () => {
    const cat = classifier.classify(
      'OpenAI Announces Next-Gen LLM with Autonomous Agent Tool Calling',
      'The new transformer model optimizes inference latency for reasoning tasks.'
    );
    expect(cat).toBe('AI & Machine Learning');
  });

  test('classifies Cybersecurity stories', () => {
    const cat = classifier.classify(
      'CISA Issues Emergency Advisory on Critical Zero-Day Vulnerability',
      'Security researchers release patch for remote code execution exploit.'
    );
    expect(cat).toBe('Cybersecurity');
  });

  test('classifies Hardware stories', () => {
    const cat = classifier.classify(
      'TSMC Begins 2nm Wafer Mass Production with Nanosheet Transistors',
      'Advanced packaging and silicon foundry enhancements yield higher processor clock speeds.'
    );
    expect(cat).toBe('Hardware');
  });

  test('classifies Cloud stories', () => {
    const cat = classifier.classify(
      'AWS Deploys Managed Kubernetes Nodes with Kernel-Bypass Networking',
      'Hyperscale serverless and container infrastructure updates.'
    );
    expect(cat).toBe('Cloud');
  });

  test('classifies Space stories', () => {
    const cat = classifier.classify(
      'NASA Lunar Lander Completes Autonomous Optical Orbital Navigation Test',
      'Spacecraft communicates via laser crosslinks in low-Earth orbit.'
    );
    expect(cat).toBe('Space');
  });

  test('classifies Science stories', () => {
    const cat = classifier.classify(
      'Fault-Tolerant Quantum Qubits Reach Millisecond Coherence Milestone',
      'Physics laboratory demonstrates neutral atom quantum error suppression.'
    );
    expect(cat).toBe('Science');
  });

  test('falls back to defaultCategory when no dominant keywords found', () => {
    const cat = classifier.classify(
      'Morning Editorial Notes and Announcements',
      'A brief greeting and calendar agenda for readers.',
      'Software'
    );
    expect(cat).toBe('Software');
  });
});
