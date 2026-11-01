export interface ICategoryClassifier {
  classify(title: string, summary: string, defaultCategory?: string): string;
}

export class KeywordCategoryClassifier implements ICategoryClassifier {
  private static readonly CATEGORIES = [
    'AI & Machine Learning',
    'Software',
    'Smartphones',
    'Hardware',
    'Cloud',
    'Cybersecurity',
    'Space',
    'Companies',
    'Startups',
    'Science',
  ] as const;

  private static readonly KEYWORDS: Record<string, string[]> = {
    'AI & Machine Learning': [
      'ai', 'artificial intelligence', 'machine learning', 'deep learning',
      'llm', 'large language model', 'gpt', 'neural network', 'generative ai',
      'diffusion model', 'transformer', 'autonomous agent', 'model weights',
      'inference', 'gemini', 'claude', 'llama', 'copilot', 'chatgpt', 'openai',
    ],
    Software: [
      'software', 'programming', 'developer', 'compiler', 'rust', 'python',
      'javascript', 'typescript', 'open source', 'github', 'framework',
      'library', 'sdk', 'wasm', 'webassembly', 'operating system', 'linux kernel',
      'git', 'ide', 'codebase', 'repository', 'algorithm',
    ],
    Smartphones: [
      'smartphone', 'iphone', 'android', 'mobile phone', 'handset', 'folding display',
      'pixel phone', 'galaxy', 'snapdragon', 'mobile camera', 'screen refresh',
      'battery health', 'cellular', '5g',
    ],
    Hardware: [
      'hardware', 'semiconductor', 'chip', 'processor', 'gpu', 'cpu',
      'memory', 'hbm', 'nanometer', 'foundry', 'tsmc', 'intel', 'nvidia',
      'wafer', 'transistor', 'silicon', 'interconnect', 'microarchitecture',
    ],
    Cloud: [
      'cloud', 'aws', 'azure', 'google cloud', 'kubernetes', 'serverless',
      'microservices', 'container', 'docker', 'data center', 'hyperscale',
      'infrastructure as code', 's3', 'ec2', 'virtual machine',
    ],
    Cybersecurity: [
      'cybersecurity', 'vulnerability', 'cve', 'ransomware', 'breach', 'zero-day',
      'malware', 'encryption', 'patch', 'phishing', 'threat actor', 'cisa',
      'security advisory', 'exploit', 'cryptography', 'firewall', 'zero trust',
    ],
    Space: [
      'space', 'nasa', 'orbit', 'rocket', 'satellite', 'lunar', 'moon',
      'mars', 'astronaut', 'telescope', 'spacex', 'launch vehicle',
      'constellation', 'interplanetary', 'aerospace',
    ],
    Companies: [
      'merger', 'acquisition', 'earnings', 'revenue', 'quarterly', 'antitrust',
      'sec filing', 'ceo', 'board of directors', 'valuation', 'stock',
      'enterprise agreement', 'restructuring',
    ],
    Startups: [
      'startup', 'venture capital', 'seed round', 'series a', 'series b',
      'funding round', 'incubator', 'accelerator', 'angel investor', 'founders',
      'early-stage', 'pre-seed', 'bootstrapped',
    ],
    Science: [
      'quantum', 'physics', 'biotech', 'fusion energy', 'superconductor',
      'genetics', 'laboratory', 'qubit', 'photon', 'entanglement',
      'neutral atom', 'cellular biology', 'astronomy',
    ],
  };

  /**
   * Classifies an article deterministically using weighted keyword matching.
   * Title keywords carry 3x weight compared to summary keywords.
   */
  classify(title: string, summary: string, defaultCategory?: string): string {
    const titleLower = title.toLowerCase();
    const summaryLower = summary.toLowerCase();

    let bestCategory = defaultCategory && KeywordCategoryClassifier.CATEGORIES.includes(defaultCategory as any)
      ? defaultCategory
      : 'Software';

    let maxScore = 0;

    for (const [category, keywords] of Object.entries(KeywordCategoryClassifier.KEYWORDS)) {
      let score = 0;

      for (const kw of keywords) {
        // Word boundary check to prevent substring false positives (e.g. "ai" inside "claim")
        const regex = new RegExp(`\\b${kw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'i');

        if (regex.test(titleLower)) {
          score += 3;
        } else if (regex.test(summaryLower)) {
          score += 1;
        }
      }

      if (score > maxScore) {
        maxScore = score;
        bestCategory = category;
      }
    }

    // Require a minimum score threshold of 2 to override default category
    if (maxScore < 2 && defaultCategory) {
      return defaultCategory;
    }

    return bestCategory;
  }
}
