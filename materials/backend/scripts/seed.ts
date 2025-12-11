/**
 * Seed Script
 * Populate MongoDB with sample data for development/testing
 *
 * Usage: npx ts-node scripts/seed.ts
 */

import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';

// Load environment variables
dotenv.config({ path: path.resolve(__dirname, '../.env') });

// Import models
import { User, Post, Comment } from '../src/models';

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/blogapp?directConnection=true';

// Sample data
const sampleUsers = [
  {
    oid: 'sample-user-001',
    email: 'alice@example.com',
    displayName: 'Alice Johnson',
    username: 'alice',
    bio: 'Full-stack developer passionate about Azure and cloud architecture.',
    isActive: true,
    role: 'user' as const,
  },
  {
    oid: 'sample-user-002',
    email: 'bob@example.com',
    displayName: 'Bob Smith',
    username: 'bob',
    bio: 'DevOps engineer with 5 years of AWS experience, now learning Azure.',
    isActive: true,
    role: 'user' as const,
  },
  {
    oid: 'sample-user-003',
    email: 'carol@example.com',
    displayName: 'Carol Williams',
    username: 'carol',
    bio: 'Cloud architect specializing in hybrid cloud solutions.',
    isActive: true,
    role: 'admin' as const,
  },
];

const samplePosts = [
  {
    title: 'Getting Started with Azure Virtual Machines',
    slug: 'getting-started-azure-vms',
    content: `# Getting Started with Azure Virtual Machines

Azure Virtual Machines (VMs) are one of the core IaaS offerings in Microsoft Azure. For those coming from AWS, think of them as the equivalent of EC2 instances.

## Key Concepts

### Availability Zones
Azure Availability Zones are physically separate locations within an Azure region. Each zone has independent power, cooling, and networking.

**AWS Equivalent**: This is similar to AWS Availability Zones.

### Virtual Machine Scale Sets
VM Scale Sets allow you to create and manage a group of identical, load-balanced VMs.

**AWS Equivalent**: This is similar to AWS Auto Scaling Groups.

## Creating Your First VM

1. Navigate to the Azure Portal
2. Click "Create a resource"
3. Select "Virtual Machine"
4. Configure the basics (subscription, resource group, region)
5. Choose your image and size
6. Configure networking
7. Review and create

## Best Practices

- Always use Managed Disks
- Distribute VMs across Availability Zones for high availability
- Use Azure Monitor for monitoring and alerting
- Implement proper backup strategies with Azure Backup

Happy learning!`,
    excerpt: 'Learn how to create and manage Azure Virtual Machines, with comparisons to AWS EC2 for those transitioning from AWS.',
    status: 'published' as const,
    tags: ['azure', 'iaas', 'virtual-machines', 'tutorial'],
    viewCount: 142,
  },
  {
    title: 'Understanding Azure Networking for AWS Engineers',
    slug: 'azure-networking-for-aws-engineers',
    content: `# Understanding Azure Networking for AWS Engineers

If you're coming from AWS, Azure networking concepts will feel familiar but have some key differences.

## VNet vs VPC

| Azure | AWS |
|-------|-----|
| Virtual Network (VNet) | VPC |
| Subnet | Subnet |
| Network Security Group (NSG) | Security Group |
| Azure Firewall | AWS Network Firewall |
| Application Gateway | Application Load Balancer |

## Key Differences

### Address Space
Azure VNets can have multiple address spaces, while AWS VPCs have a single CIDR block (with secondary CIDRs).

### Subnets
Azure subnets span all Availability Zones by default. In AWS, subnets are zone-specific.

### Load Balancers
Azure has:
- **Basic Load Balancer**: Free, limited features
- **Standard Load Balancer**: Zone-redundant, more features

This is different from AWS where all ALB/NLB have similar pricing models.

## Hands-On: Creating a VNet

\`\`\`bicep
resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'vnet-workshop'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'web-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }
    ]
  }
}
\`\`\`

Understanding these differences will help you design better Azure architectures!`,
    excerpt: 'A comprehensive comparison of Azure and AWS networking concepts for engineers transitioning to Azure.',
    status: 'published' as const,
    tags: ['azure', 'networking', 'aws', 'comparison'],
    viewCount: 256,
  },
  {
    title: 'Implementing High Availability with Azure Load Balancer',
    slug: 'high-availability-azure-load-balancer',
    content: `# Implementing High Availability with Azure Load Balancer

High availability is crucial for production workloads. This post covers how to use Azure Load Balancer to distribute traffic across multiple VMs.

## Types of Azure Load Balancers

### External (Public) Load Balancer
- Public IP address
- Distributes internet traffic to VMs
- **AWS Equivalent**: Application Load Balancer (ALB) or Network Load Balancer (NLB)

### Internal Load Balancer
- Private IP address
- Distributes traffic within a VNet
- **AWS Equivalent**: Internal ALB/NLB

## Architecture Pattern

\`\`\`
Internet
    |
    v
[External LB]
    |
    v
[Web Tier VMs] ---- Zone 1, Zone 2
    |
    v
[Internal LB]
    |
    v
[App Tier VMs] ---- Zone 1, Zone 2
    |
    v
[MongoDB Replica Set]
\`\`\`

## Health Probes

Configure health probes to ensure traffic only goes to healthy instances:

- **HTTP Probe**: Check a specific endpoint (e.g., /health)
- **TCP Probe**: Check if a port is open
- **HTTPS Probe**: Similar to HTTP but with TLS

## Best Practices

1. Use Standard SKU (not Basic) for production
2. Enable zone-redundancy
3. Configure appropriate health probe intervals
4. Use connection draining for graceful shutdowns

This pattern ensures your application remains available even if individual VMs fail!`,
    excerpt: 'Learn how to implement high availability using Azure Load Balancer with a multi-tier architecture.',
    status: 'published' as const,
    tags: ['azure', 'load-balancer', 'high-availability', 'architecture'],
    viewCount: 189,
  },
  {
    title: 'Draft: Azure Site Recovery Deep Dive',
    slug: 'azure-site-recovery-deep-dive',
    content: `# Azure Site Recovery Deep Dive

*This is a draft post - work in progress*

## Introduction

Azure Site Recovery (ASR) provides disaster recovery for Azure VMs...

TODO:
- [ ] Add replication architecture diagram
- [ ] Include failover procedures
- [ ] Add cost considerations
- [ ] Compare with AWS DRS`,
    excerpt: 'A deep dive into Azure Site Recovery for disaster recovery scenarios.',
    status: 'draft' as const,
    tags: ['azure', 'disaster-recovery', 'asr'],
    viewCount: 0,
  },
];

const sampleComments = [
  {
    postSlug: 'getting-started-azure-vms',
    content: 'Great introduction! The AWS comparisons really helped me understand the concepts faster.',
    userIndex: 1, // Bob
  },
  {
    postSlug: 'getting-started-azure-vms',
    content: 'Thanks for this! One question - how do VM sizes compare between Azure and AWS?',
    userIndex: 2, // Carol
  },
  {
    postSlug: 'azure-networking-for-aws-engineers',
    content: 'The table comparison is super helpful. Bookmarked this for reference!',
    userIndex: 0, // Alice
  },
  {
    postSlug: 'high-availability-azure-load-balancer',
    content: 'This is exactly the architecture pattern we\'re implementing for our workshop project.',
    userIndex: 1, // Bob
  },
];

async function seed(): Promise<void> {
  try {
    console.log('🌱 Starting database seed...');
    console.log(`📦 Connecting to: ${MONGODB_URI.replace(/\/\/.*@/, '//***:***@')}`);

    await mongoose.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB');

    // Clear existing data
    console.log('🗑️  Clearing existing data...');
    await Promise.all([
      User.deleteMany({}),
      Post.deleteMany({}),
      Comment.deleteMany({}),
    ]);

    // Create users
    console.log('👥 Creating users...');
    const users = await User.insertMany(sampleUsers);
    console.log(`   Created ${users.length} users`);

    // Create posts
    console.log('📝 Creating posts...');
    const postsWithAuthors = samplePosts.map((post, index) => ({
      ...post,
      author: users[index % users.length]!._id,
      publishedAt: post.status === 'published' ? new Date(Date.now() - index * 86400000) : undefined,
    }));
    const posts = await Post.insertMany(postsWithAuthors);
    console.log(`   Created ${posts.length} posts`);

    // Create comments
    console.log('💬 Creating comments...');
    const commentsToCreate = [];
    for (const commentData of sampleComments) {
      const post = posts.find((p) => p.slug === commentData.postSlug);
      if (post) {
        commentsToCreate.push({
          post: post._id,
          author: users[commentData.userIndex]!._id,
          content: commentData.content,
          isEdited: false,
          isDeleted: false,
        });
      }
    }
    const comments = await Comment.insertMany(commentsToCreate);
    console.log(`   Created ${comments.length} comments`);

    console.log('');
    console.log('✨ Seed completed successfully!');
    console.log('');
    console.log('📊 Summary:');
    console.log(`   - Users: ${users.length}`);
    console.log(`   - Posts: ${posts.length} (${posts.filter((p) => p.status === 'published').length} published)`);
    console.log(`   - Comments: ${comments.length}`);
    console.log('');
    console.log('🔗 Test the API:');
    console.log('   curl http://localhost:3000/api/posts');
    console.log('   curl http://localhost:3000/api/posts/getting-started-azure-vms');
  } catch (error) {
    console.error('❌ Seed failed:', error);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    console.log('👋 Disconnected from MongoDB');
  }
}

seed();
