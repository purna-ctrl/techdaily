import '../models/article.dart';

/// Local article service providing realistic sample data for Phase 1 UI testing.
/// NOTE: All articles below are explicitly DEMO/SAMPLE articles designed to illustrate
/// the TechDaily newspaper layout, typography, and section hierarchy without fabricating
/// real-world current events.
class LocalArticleService {
  static final List<Article> sampleArticles = [
    // 1. AI & Machine Learning - Breaking
    Article(
      id: 'demo-ai-01',
      title: 'Next-Generation Model Distillation Shrinks Frontier LLMs for On-Device Execution',
      summary: 'Researchers demonstrate structured pruning and speculative decoding methods that compress 70B parameter capability down to 7B consumer device targets.',
      simpleExplanation: 'Clever compression techniques allow sophisticated AI thinking capabilities to run directly on smartphones without sending your data to the cloud.',
      category: 'AI & Machine Learning',
      sourceName: 'Google Official Blog',
      sourceUrl: 'https://blog.google/technology/ai/',
      publishedAt: DateTime.now().subtract(const Duration(hours: 2)),
      isBreaking: true,
      keyPoints: [
        'Pruning preserves 94% of reasoning capabilities while reducing memory footprint by 65%',
        'Speculative decoding delivers a 2.4x latency speedup on consumer mobile chips',
        'Zero cloud reliance ensures complete privacy for sensitive queries',
      ],
      whatHappened: 'A newly published technical milestone details how recursive layer-pruning combined with knowledge distillation enables compact language models to match previous generations of giant datacenter models on mathematical and logical reasoning tasks.',
      whyItMatters: 'Running models locally drastically lowers cloud API costs for developers, minimizes energy consumption in hyperscale datacenters, and guarantees user data never leaves the handset.',
      simpleExplanationTranslations: {
        'hi': 'नई कंप्रेशन तकनीकों की मदद से समझदार AI सीधे आपके स्मार्टफ़ोन पर चल सकता है, और आपका डेटा क्लाउड पर भेजने की ज़रूरत नहीं पड़ती।',
        'te': 'కొత్త కంప్రెషన్ పద్ధతుల వల్ల తెలివైన AI నేరుగా మీ స్మార్ట్‌ఫోన్‌లోనే పనిచేస్తుంది, మీ డేటాను క్లౌడ్‌కు పంపాల్సిన అవసరం ఉండదు.',
        'ta': 'புதிய சுருக்க நுட்பங்களால் புத்திசாலித்தனமான AI நேரடியாக உங்கள் ஸ்மார்ட்போனிலேயே இயங்கும்; உங்கள் தரவை கிளவுடுக்கு அனுப்ப வேண்டியதில்லை.',
      },
    ),

    // 2. Hardware - Breaking
    Article(
      id: 'demo-hw-01',
      title: 'High-Bandwidth Memory HBM4 Architecture Standard Finalized with 2048-Bit Interface',
      summary: 'Semiconductor industry standards body JEDEC publishes HBM4 specs, doubling interface width to meet next-decade AI accelerator memory bandwidth demands.',
      simpleExplanation: 'Computer chip memory has doubled its highway lanes, allowing AI accelerator chips to read and write information at record-breaking speeds.',
      category: 'Hardware',
      sourceName: 'NVIDIA Official Newsroom',
      sourceUrl: 'https://nvidianews.nvidia.com',
      publishedAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 15)),
      isBreaking: true,
      keyPoints: [
        'Interface width increases from 1024 bits in HBM3E to 2048 bits in HBM4',
        'Theoretical bandwidth exceeds 1.5 TB/s per stack',
        'Direct bonding to logic dies eliminates silicon interposers in advanced packaging',
      ],
      whatHappened: 'The JEDEC Solid State Technology Association officially ratified the HBM4 standard, bringing radical architectural changes including custom logic base dies manufactured on advanced foundry nodes.',
      whyItMatters: 'Memory bandwidth has been the primary bottleneck in scaling large AI training clusters. HBM4 allows hardware architects to train larger models with fewer physical accelerators.',
    ),

    // 3. Software
    Article(
      id: 'demo-sw-01',
      title: 'WebAssembly System Interface (WASI 0.2) Standard Stabilizes Portable Cloud Workloads',
      summary: 'The Bytecode Alliance releases the official Component Model specification, establishing modular, language-agnostic binaries for high-performance microservices.',
      simpleExplanation: 'Programs written in languages like Rust, Go, or C can now run anywhere—from browser tabs to cloud servers—securely and instantly without bulky virtual machines.',
      category: 'Software',
      sourceName: 'GitHub Blog',
      sourceUrl: 'https://github.blog',
      publishedAt: DateTime.now().subtract(const Duration(hours: 5)),
      keyPoints: [
        'Introduces the WebAssembly Component Model for plug-and-play composability',
        'Sub-millisecond cold starts replace container boot times',
        'Fine-grained capability-based security restricts socket and filesystem access',
      ],
      whatHappened: 'After years of collaborative design, the WASI 0.2 milestone provides stable networking and filesystem interfaces, enabling enterprise developers to deploy language-neutral components across heterogeneous environments.',
      whyItMatters: 'WASI provides a compelling alternative to traditional Docker containers for event-driven functions and edge computing, slashing boot latency and infrastructure overhead.',
    ),

    // 4. Cybersecurity
    Article(
      id: 'demo-sec-01',
      title: 'Global Cryptographic Transition: NIST Releases Primary Post-Quantum Encryption Standards',
      summary: 'Federal and international cybersecurity authorities formalize ML-KEM and ML-DSA algorithms, kicking off a worldwide migration away from RSA and elliptic curves.',
      simpleExplanation: 'Security agencies have released math problems so complex that even future quantum supercomputers will not be able to crack your passwords or encrypted messages.',
      category: 'Cybersecurity',
      sourceName: 'Reuters',
      sourceUrl: 'https://www.reuters.com/technology',
      publishedAt: DateTime.now().subtract(const Duration(hours: 6)),
      keyPoints: [
        'ML-KEM (Module-Lattice Key Encapsulation) replaces traditional Diffie-Hellman',
        'ML-DSA (Module-Lattice Digital Signatures) secures certificate authorities',
        'Enterprises given multi-year roadmaps to remediate legacy cryptographic libraries',
      ],
      whatHappened: 'The National Institute of Standards and Technology completed its eight-year evaluation process, releasing definitive standard code for algorithms designed to resist cryptanalytic attacks by quantum computers.',
      whyItMatters: 'Adversaries collecting encrypted internet traffic today could decipher it in the future once quantum hardware matures. Migrating to lattice cryptography protects sensitive long-term communications now.',
    ),

    // 5. Smartphones
    Article(
      id: 'demo-phone-01',
      title: '2-Nanometer Gate-All-Around Foundry Yields Meet Flagship Smartphone Production Targets',
      summary: 'Foundry testing verifies 15% clock speed improvements and 30% power reductions as smartphones prepare for nanosheet transistor architecture.',
      simpleExplanation: 'Phone microprocessors are shrinking their transistors again, providing significantly longer battery life while making phone cameras and games noticeably faster.',
      category: 'Smartphones',
      sourceName: 'Associated Press',
      sourceUrl: 'https://apnews.com/hub/technology',
      publishedAt: DateTime.now().subtract(const Duration(hours: 8)),
      keyPoints: [
        'Transition from FinFET to Gate-All-Around (GAA) nanosheets minimizes electrical leakage',
        'Backside power delivery networks (BSPDN) reduce IR voltage drop across the chip',
        'First consumer handhelds expected to adopt the new silicon within two quarters',
      ],
      whatHappened: 'Semiconductor manufacturers confirmed that test runs of 2nm GAA wafers achieved defect density thresholds required for commercial volume fabrication targeting premium mobile devices.',
      whyItMatters: 'Thermal constraints are the biggest barrier to running sustained machine learning and 3D rendering on smartphones. Greater power efficiency prevents thermal throttling during heavy workloads.',
    ),

    // 6. Cloud
    Article(
      id: 'demo-cloud-01',
      title: 'Hyperscale Kubernetes Clusters Adopt Automated Kernel-Bypass Networking',
      summary: 'Data center operators roll out eBPF-driven bypass mechanisms to eliminate network stack virtualization penalties in multi-tenant cloud environments.',
      simpleExplanation: 'Cloud servers are using clever shortcuts in their internal plumbing to move internet traffic between applications with nearly zero delay.',
      category: 'Cloud',
      sourceName: 'AWS Official Blog',
      sourceUrl: 'https://aws.amazon.com/blogs/aws',
      publishedAt: DateTime.now().subtract(const Duration(hours: 10)),
      keyPoints: [
        'Packet handling overhead drops by 40% across distributed services',
        'eBPF programs run verified safety checks inside the Linux kernel',
        'Decreases CPU cycles devoted to socket routing, freeing cores for application logic',
      ],
      whatHappened: 'Major cloud providers have standardized on kernel-bypass networking frameworks powered by extended Berkeley Packet Filters (eBPF), accelerating inter-node communication across large clusters.',
      whyItMatters: 'As distributed AI applications exchange millions of parameters simultaneously, reducing network overhead directly lowers cluster idle times and optimizes cloud infrastructure spend.',
    ),

    // 7. Space
    Article(
      id: 'demo-space-01',
      title: 'Inter-Satellite Laser Crosslinks Achieve 100 Gbps Low-Earth Orbit Data Relays',
      summary: 'Orbital optical communications mesh connects commercial satellite constellations, bypassing terrestrial fiber bottlenecks across ocean expanses.',
      simpleExplanation: 'Satellites are now beaming internet data directly between each other in space using precision laser beams at speeds rivaling underwater fiber optic cables.',
      category: 'Space',
      sourceName: 'BBC News Technology',
      sourceUrl: 'https://www.bbc.com/news/technology',
      publishedAt: DateTime.now().subtract(const Duration(hours: 12)),
      keyPoints: [
        'Laser links maintain micro-radian pointing precision over 5,000 kilometer distances',
        'Eliminates reliance on ground tracking stations in remote or politically unstable areas',
        'Cuts round-trip latency between London and Tokyo by over 25 milliseconds',
      ],
      whatHappened: 'Satellite fleet operators demonstrated continuous 100 Gbps optical transport across five orbital planes, creating a true space-based mesh backbone without routing down to ground relay stations.',
      whyItMatters: 'Light travels faster in the vacuum of space than through glass fiber, meaning space-routed internet packets can outpace undersea cables for ultra-low latency global trade and communications.',
    ),

    // 8. Startups
    Article(
      id: 'demo-startup-01',
      title: 'Silicon Anode Battery Startup Scales Continuous Roll-to-Roll Pilot Line',
      summary: 'Next-generation battery developer achieves 450 Wh/kg energy density by replacing graphite anodes with pre-lithiated porous silicon structures.',
      simpleExplanation: 'A promising hardware startup has figured out how to manufacture batteries that store nearly double the energy in the same physical size.',
      category: 'Startups',
      sourceName: 'Reuters',
      sourceUrl: 'https://www.reuters.com/technology',
      publishedAt: DateTime.now().subtract(const Duration(hours: 14)),
      keyPoints: [
        'Energy density jumps from commercial standard 260 Wh/kg to 450 Wh/kg',
        'Porous matrix accommodates 300% silicon expansion during charging without degradation',
        'Pilot facility begins shipping sample pouch cells to consumer electronics OEMs',
      ],
      whatHappened: 'After five years of materials research, an MIT spinout demonstrated that continuous coating machinery can produce durable silicon anodes at commercial scale with 1,000-cycle retention rates.',
      whyItMatters: 'Doubling battery energy density could yield multi-day smartphone battery life and radically lighter electric aircraft, unlocking consumer form factors previously limited by battery weight.',
    ),

    // 9. Science
    Article(
      id: 'demo-sci-01',
      title: 'Fault-Tolerant Logical Qubits Demonstrate Threshold Error Suppression in Neutral Atom System',
      summary: 'Quantum computing researchers shuttle thousands of rubidium atoms using optical tweezers to synthesize 48 error-corrected logical qubits.',
      simpleExplanation: 'Scientists have built a quantum computer that can actively catch and fix its own tiny calculation errors while they happen.',
      category: 'Science',
      sourceName: 'Microsoft Official Blog',
      sourceUrl: 'https://blogs.microsoft.com',
      publishedAt: DateTime.now().subtract(const Duration(hours: 18)),
      keyPoints: [
        'Logical error rate drops exponentially as code distance increases',
        'Neutral atom array reconfigures quantum circuits dynamically in real time',
        'Completes complex entanglement benchmarks that would take classical supercomputers weeks',
      ],
      whatHappened: 'A research consortium demonstrated that neutral atoms held in place by laser tweezers can execute surface codes that continuously detect and correct bit and phase flip errors during computation.',
      whyItMatters: 'Noise and decoherence have long prevented quantum processors from performing practical calculations. Fault-tolerant logical qubits represent the necessary breakthrough toward useful quantum chemistry simulations.',
    ),

    // 10. Companies
    Article(
      id: 'demo-comp-01',
      title: 'Enterprise Software Consortium Adopts Open Telemetry Standards for AI Observability',
      summary: 'Leading enterprise cloud providers harmonize metrics, traces, and token usage telemetry under the Cloud Native Computing Foundation.',
      simpleExplanation: 'The biggest software companies have agreed on a single measurement system so developers can monitor how AI applications perform across different cloud systems.',
      category: 'Companies',
      sourceName: 'Google Cloud Blog',
      sourceUrl: 'https://cloud.google.com/blog',
      publishedAt: DateTime.now().subtract(const Duration(hours: 22)),
      keyPoints: [
        'Unified semantic conventions for prompt token counts, latencies, and agent steps',
        'Vendors pledge vendor-neutral export formats to prevent monitoring lock-in',
        'Integrated into standard OpenTelemetry collectors for Kubernetes workloads',
      ],
      whatHappened: 'Dozens of enterprise tech companies announced joint contributions to the OpenTelemetry semantic specifications, establishing standardized instrumentation for LLM inference calls and multi-agent systems.',
      whyItMatters: 'Without uniform observability, enterprise software teams struggle to track ballooning API costs, diagnose hallucination regressions, or ensure compliance across disparate AI vendors.',
    ),

    // 11. AI & Machine Learning
    Article(
      id: 'demo-ai-02',
      title: 'Reinforcement Learning from Environment Feedback (RLEF) Transforms Autonomous Coding Agents',
      summary: 'New training paradigms give code generation models sandbox execution feedback, resulting in self-debugging capabilities across complex repository tasks.',
      simpleExplanation: 'Instead of just guessing code, AI programming assistants can now run their own code in private testing environments and fix their own mistakes before answering.',
      category: 'AI & Machine Learning',
      sourceName: 'OpenAI Official Blog',
      sourceUrl: 'https://openai.com/news',
      publishedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      keyPoints: [
        'Autonomous agent solves 58% of real-world GitHub issues on SWE-bench benchmarks',
        'Iterative self-correction loop catches compiler errors, lint violations, and failing tests',
        'Drastically reduces human oversight needed during repetitive refactoring tasks',
      ],
      whatHappened: 'A research milestone details an agent architecture that leverages sandboxed terminals to execute unit tests and analyze runtime traces, enabling models to verify their work before committing changes.',
      whyItMatters: 'Coding tools are moving from autocomplete snippets to full end-to-end software engineering agents capable of managing dependencies, migrations, and bug resolutions.',
    ),

    // 12. Software
    Article(
      id: 'demo-sw-02',
      title: 'Linux Kernel 6.14 Integrates Memory Safety Enhancements in Core Device Drivers',
      summary: 'Upstream maintainers merge formal verification tooling and expanded safe abstraction layers into subsystem drivers.',
      simpleExplanation: 'The core operating system that powers Android and cloud servers has added new safety barriers to prevent hackers from exploiting memory glitches.',
      category: 'Software',
      sourceName: 'GitHub Blog',
      sourceUrl: 'https://github.blog',
      publishedAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
      keyPoints: [
        'Expands safe driver abstractions to PCIe and direct memory access (DMA) subsystems',
        'Static analysis tools catch potential use-after-free conditions before compilation',
        'Performance benchmarks demonstrate zero measurable overhead compared to legacy C drivers',
      ],
      whatHappened: 'The latest mainline Linux kernel release includes hardened driver interfaces designed to eliminate buffer overflows and concurrency races in network and storage controllers.',
      whyItMatters: 'Over 70% of historical operating system vulnerabilities trace back to memory management bugs. Hardening driver layers neutralizes the single largest attack vector in modern infrastructure.',
    ),

    // 13. Hardware
    Article(
      id: 'demo-hw-02',
      title: 'Co-Packaged Optics Breakthrough Replaces Copper Traces in Next-Generation AI Switches',
      summary: 'Silicon photonics transceivers integrated directly onto the switch substrate cut interconnect power dissipation by 70% in high-speed fabric designs.',
      simpleExplanation: 'Data center switches are replacing traditional copper wires with microscopic laser beams directly on the chip, saving enormous amounts of electricity.',
      category: 'Hardware',
      sourceName: 'Associated Press',
      sourceUrl: 'https://apnews.com/hub/technology',
      publishedAt: DateTime.now().subtract(const Duration(days: 1, hours: 8)),
      keyPoints: [
        'Transfers 3.2 Terabits per second per optical engine',
        'Cuts thermal dissipation significantly, simplifying liquid cooling loops',
        'Enables single-hop optical fabrics connecting up to 64,000 computing nodes',
      ],
      whatHappened: 'Hardware engineers demonstrated co-packaged optics (CPO) modules that couple fiber cables directly to the processor package, eliminating power-hungry signal retimers.',
      whyItMatters: 'Electrical signals passing through copper cables degrade rapidly at speeds above 100 Gbps. Moving to optical interconnects removes a fundamental thermal ceiling in supercomputer design.',
    ),

    // 14. Cybersecurity
    Article(
      id: 'demo-sec-02',
      title: 'Zero-Trust Architecture Mandate Accelerates Adoption of Cryptographic Identity Attestation',
      summary: 'Enterprises phase out static passwords and long-lived API tokens in favor of short-lived cryptographic credentials tied to hardware security modules (HSMs).',
      simpleExplanation: 'Companies are banning permanent computer passwords and secret keys, replacing them with temporary digital badges that verify identity through secure hardware chips.',
      category: 'Cybersecurity',
      sourceName: 'BBC News Technology',
      sourceUrl: 'https://www.bbc.com/news/technology',
      publishedAt: DateTime.now().subtract(const Duration(days: 1, hours: 12)),
      keyPoints: [
        'Eliminates password reuse and phishing-related credential compromises',
        'Credentials expire within minutes unless refreshed by hardware-bound challenge responses',
        'SPIFFE/SPIRE standards allow seamless identity federation across cloud providers',
      ],
      whatHappened: 'A security consortium released guidelines showing that over 60% of Fortune 500 security teams have migrated internal services to workload identity federation, removing hardcoded credentials from source code.',
      whyItMatters: 'Leaked API keys and service account credentials represent the primary vector in cloud data breaches. Hardware-bound ephemeral credentials ensure stolen tokens are useless to attackers.',
    ),

    // 15. Smartphones
    Article(
      id: 'demo-phone-02',
      title: 'Foldable Display Durability Surpasses 500,000 Bends with Ceramic-Infused UTG Glass',
      summary: 'New ultra-thin flexible glass compositions and teardrop hinge mechanisms nearly eliminate visible crease lines while doubling impact resistance.',
      simpleExplanation: 'Folding phone screens have become twice as tough, virtually eliminating the crease line down the middle of the display.',
      category: 'Smartphones',
      sourceName: 'Apple Newsroom',
      sourceUrl: 'https://www.apple.com/newsroom',
      publishedAt: DateTime.now().subtract(const Duration(days: 1, hours: 16)),
      keyPoints: [
        'Rated for 500,000 fold cycles, equivalent to 10 years of typical usage',
        'Zero-gap hinge prevents dust and debris ingress into the internal chassis',
        'Drop-test resistance on hard surfaces matches traditional rigid smartphones',
      ],
      whatHappened: 'Display manufacturers showcased flexible panels utilizing nanoscale ceramic crystallites embedded in ultra-thin glass, resolving long-standing longevity and scratch resistance concerns.',
      whyItMatters: 'Durability anxieties have been the biggest deterrent for mainstream smartphone buyers considering foldable devices. Improved screen resilience paves the way for wider consumer adoption.',
    ),

    // 16. Cloud
    Article(
      id: 'demo-cloud-02',
      title: 'MicroVM Snapshots Reduce Serverless Cold-Start Delays to Under Five Milliseconds',
      summary: 'Snapshot-resumption frameworks allow serverless functions to wake up with pre-initialized runtime memory states, matching traditional resident server performance.',
      simpleExplanation: 'On-demand cloud programs that used to take seconds to warm up can now instantly snap awake in the blink of an eye.',
      category: 'Cloud',
      sourceName: 'AWS Official Blog',
      sourceUrl: 'https://aws.amazon.com/blogs/aws',
      publishedAt: DateTime.now().subtract(const Duration(days: 2, hours: 3)),
      keyPoints: [
        'Memory pages are streamed incrementally on-demand as execution begins',
        'Reduces cold-start latency from 1,200ms down to 4.2ms for heavy JVM and Python workloads',
        'Lowers idle server costs by allowing aggressive scale-to-zero configurations',
      ],
      whatHappened: 'Cloud infrastructure engineers revealed performance benchmarks for copy-on-write memory resumption that instantaneously boots virtual environments without running full runtime initialization sequences.',
      whyItMatters: 'Cold-start latency has historically prevented developers from using cost-effective serverless architectures for latency-sensitive APIs. Instant resumption makes serverless practical for almost every web service.',
    ),

    // 17. Space
    Article(
      id: 'demo-space-02',
      title: 'Autonomous Vision-Guided Rendezvous Enables Robotic Servicing of Geosynchronous Satellites',
      summary: 'Orbital refueling vehicle successfully docks with aging communications satellite to replenish propellants and extend operational life by five years.',
      simpleExplanation: 'A space repair robot flew up to an old satellite in high orbit, carefully docked with it, and pumped fresh fuel into its tanks to keep it working.',
      category: 'Space',
      sourceName: 'Reuters',
      sourceUrl: 'https://www.reuters.com/technology',
      publishedAt: DateTime.now().subtract(const Duration(days: 2, hours: 8)),
      keyPoints: [
        'First fully autonomous docking conducted without human remote joystick intervention',
        'Pumps hydrazine and xenon propellants through universal mechanical interfaces',
        'Provides an economical alternative to commissioning multi-hundred-million dollar replacement satellites',
      ],
      whatHappened: 'A commercial mission extension vehicle demonstrated precision visual odometry and robotic grappling to dock with a commercial broadcasting satellite 36,000 kilometers above the Earth.',
      whyItMatters: 'Extending the lifespan of existing spacecraft significantly reduces orbital debris and changes the economics of satellite communications by treating orbiters as maintainable assets.',
    ),

    // 18. Startups
    Article(
      id: 'demo-startup-02',
      title: 'Developer-First Synthetic Data Platform Generates High-Fidelity Edge Cases for Autonomous Vehicles',
      summary: 'AI startup secures Series A to scale physics-accurate sensor simulation pipelines for robotics, autonomous driving, and industrial automation teams.',
      simpleExplanation: 'A new startup lets self-driving car makers test dangerous and rare scenarios—like icy storms or sudden obstacles—inside realistic virtual worlds.',
      category: 'Startups',
      sourceName: 'Associated Press',
      sourceUrl: 'https://apnews.com/hub/technology',
      publishedAt: DateTime.now().subtract(const Duration(days: 2, hours: 14)),
      keyPoints: [
        'Generates photorealistic LiDAR, radar, and multi-camera feeds with Ray-Tracing precision',
        'Simulates corner cases that are too hazardous or rare to collect on physical roads',
        'Decreases perception model training time from months to weeks',
      ],
      whatHappened: 'Robotics teams announced the deployment of synthetic data engines that combine differentiable physics simulation with generative diffusion to recreate long-tail driving anomalies.',
      whyItMatters: 'Physical road testing cannot safely encounter every hazardous combination of weather and human behavior. Accurate synthetic generation ensures autonomous systems are prepared for rare crises.',
    ),
  ];

  /// Returns all demo articles
  Future<List<Article>> getSampleArticles() async {
    // Small artificial delay to simulate realistic data source retrieval
    await Future.delayed(const Duration(milliseconds: 50));
    return List<Article>.from(sampleArticles);
  }
}
