class TrustedSource {
  final String id;
  final String name;
  final String domain;
  final String homeUrl;
  final String category;
  final String description;
  final bool isOfficialCorporate;

  const TrustedSource({
    required this.id,
    required this.name,
    required this.domain,
    required this.homeUrl,
    required this.category,
    required this.description,
    this.isOfficialCorporate = false,
  });
}

class TrustedSourcesConfig {
  static const List<TrustedSource> sources = [
    TrustedSource(
      id: 'reuters',
      name: 'Reuters',
      domain: 'reuters.com',
      homeUrl: 'https://www.reuters.com/technology',
      category: 'Global Wire Service',
      description: 'International news organization providing impartial financial and technology reporting.',
    ),
    TrustedSource(
      id: 'ap',
      name: 'Associated Press',
      domain: 'apnews.com',
      homeUrl: 'https://apnews.com/hub/technology',
      category: 'Global Wire Service',
      description: 'Independent global news organization dedicated to factual journalism.',
    ),
    TrustedSource(
      id: 'bbc',
      name: 'BBC News Technology',
      domain: 'bbc.com',
      homeUrl: 'https://www.bbc.com/news/technology',
      category: 'Public Broadcaster',
      description: 'In-depth global technology analysis and human-interest tech journalism.',
    ),
    TrustedSource(
      id: 'google-blog',
      name: 'Google Official Blog',
      domain: 'blog.google',
      homeUrl: 'https://blog.google',
      category: 'Primary Corporate Source',
      description: 'Official announcements on Android, Chrome, Gemini, Search, and AI research.',
      isOfficialCorporate: true,
    ),
    TrustedSource(
      id: 'microsoft-blog',
      name: 'Microsoft Official Blog',
      domain: 'blogs.microsoft.com',
      homeUrl: 'https://blogs.microsoft.com',
      category: 'Primary Corporate Source',
      description: 'Official releases on Windows, Azure, Copilot, enterprise platforms, and quantum computing.',
      isOfficialCorporate: true,
    ),
    TrustedSource(
      id: 'apple-newsroom',
      name: 'Apple Newsroom',
      domain: 'apple.com/newsroom',
      homeUrl: 'https://www.apple.com/newsroom',
      category: 'Primary Corporate Source',
      description: 'First-party press releases on Apple Silicon, iOS, macOS, iPadOS, and hardware.',
      isOfficialCorporate: true,
    ),
    TrustedSource(
      id: 'openai-blog',
      name: 'OpenAI Official Blog',
      domain: 'openai.com',
      homeUrl: 'https://openai.com/news',
      category: 'Primary Corporate Source',
      description: 'Direct frontier research publications, safety guidelines, and model releases.',
      isOfficialCorporate: true,
    ),
    TrustedSource(
      id: 'nvidia-newsroom',
      name: 'NVIDIA Newsroom',
      domain: 'nvidianews.nvidia.com',
      homeUrl: 'https://nvidianews.nvidia.com',
      category: 'Primary Corporate Source',
      description: 'Official updates on GPUs, CUDA architectures, Blackwell, and supercomputing.',
      isOfficialCorporate: true,
    ),
    TrustedSource(
      id: 'meta-newsroom',
      name: 'Meta Newsroom',
      domain: 'about.fb.com/news',
      homeUrl: 'https://about.fb.com/news',
      category: 'Primary Corporate Source',
      description: 'Official updates on Llama open models, PyTorch ecosystem, VR, and infrastructure.',
      isOfficialCorporate: true,
    ),
    TrustedSource(
      id: 'aws-blog',
      name: 'AWS Official Blog',
      domain: 'aws.amazon.com/blogs',
      homeUrl: 'https://aws.amazon.com/blogs/aws',
      category: 'Primary Corporate Source',
      description: 'Cloud architecture releases, bedrock models, EC2 instances, and serverless technology.',
      isOfficialCorporate: true,
    ),
    TrustedSource(
      id: 'gcp-blog',
      name: 'Google Cloud Blog',
      domain: 'cloud.google.com/blog',
      homeUrl: 'https://cloud.google.com/blog',
      category: 'Primary Corporate Source',
      description: 'Cloud infrastructure, Vertex AI, Kubernetes, and enterprise data analytics.',
      isOfficialCorporate: true,
    ),
    TrustedSource(
      id: 'github-blog',
      name: 'GitHub Blog',
      domain: 'github.blog',
      homeUrl: 'https://github.blog',
      category: 'Developer Platform',
      description: 'Developer tooling updates, Git innovations, security advisories, and Copilot features.',
      isOfficialCorporate: true,
    ),
  ];

  static bool isTrusted(String sourceName) {
    return sources.any(
      (s) => s.name.toLowerCase() == sourceName.toLowerCase() ||
             sourceName.toLowerCase().contains(s.name.toLowerCase()),
    );
  }

  static TrustedSource? findByName(String sourceName) {
    try {
      return sources.firstWhere(
        (s) => s.name.toLowerCase() == sourceName.toLowerCase() ||
               sourceName.toLowerCase().contains(s.name.toLowerCase()),
      );
    } catch (_) {
      return null;
    }
  }
}
