# Database Design Specification

## Overview

This document defines the MongoDB database architecture and schema requirements for the Azure IaaS Workshop blog application. This serves as the specification that the Database Administrator agent and Backend Engineer agent must follow when implementing the database tier and data access layer.

## Database Overview

- **Database System**: MongoDB 7.0+ (Community Edition)
- **Deployment Pattern**: Replica Set across Azure Availability Zones
- **High Availability**: Automatic failover with 2 data-bearing nodes
- **Backup Strategy**: Azure Backup (VM-level) + MongoDB native backups
- **Target Users**: Workshop students learning MongoDB HA patterns on Azure VMs
- **Educational Focus**: Demonstrate replica sets, failover, and operational practices

## MongoDB Deployment Architecture

### Replica Set Configuration

#### Topology
- **Replica Set Name**: `blogapp-rs0`
- **Architecture**: 2-node replica set (no arbiter)
- **Node Distribution**: 
  - Primary node: DB VM in Availability Zone 1 (10.0.3.4)
  - Secondary node: DB VM in Availability Zone 2 (10.0.3.5)
- **Deployment Method**: Self-managed MongoDB on Ubuntu 24.04 LTS VMs

**Why 2 Nodes Instead of 3?**
- Cost optimization for workshop (20-30 students)
- Demonstrates HA principles while keeping infrastructure simple
- Trade-off: Requires manual intervention if primary fails (educational value)
- Production recommendation: 3+ nodes documented in workshop materials

#### Replica Set Members

**Primary Node (db-vm-az1)**:
- **Role**: Primary (accepts writes and reads)
- **VM**: Standard_B4ms (4 vCPU, 16 GB RAM)
- **Availability Zone**: Zone 1
- **Private IP**: 10.0.3.4
- **MongoDB Port**: 27017 (standard default port)
- **Priority**: 2 (higher priority to prefer as primary)
- **Votes**: 1
- **Rationale**: B4ms burstable VM with 60% CPU baseline (2.4 vCPUs) + burst to 100%, sufficient for workshop MongoDB workload; supports Premium SSD for database performance

**Secondary Node (db-vm-az2)**:
- **Role**: Secondary (reads only, synchronous replication)
- **VM**: Standard_B4ms (4 vCPU, 16 GB RAM)
- **Availability Zone**: Zone 2
- **Private IP**: 10.0.3.5
- **MongoDB Port**: 27017 (standard default port)
- **Priority**: 1 (lower priority)
- **Votes**: 1
- **Rationale**: Consistent with primary node; B4ms adequate for replication and failover in workshop context with light data volumes

#### Replica Set Initialization

```javascript
// MongoDB shell command to initialize replica set
rs.initiate({
  _id: "blogapp-rs0",
  version: 1,
  members: [
    {
      _id: 0,
      host: "10.0.3.4:27017",
      priority: 2,
      votes: 1
    },
    {
      _id: 1,
      host: "10.0.3.5:27017",
      priority: 1,
      votes: 1
    }
  ]
});
```

#### Read Preference Strategy

**Application Configuration**:
- **Default**: `primaryPreferred` - Read from primary, fallback to secondary if primary unavailable
- **Reason**: Ensures read-after-write consistency for blog posts while allowing failover reads
- **Alternative**: `primary` for strict consistency (document as option)

#### Write Concern

**Production-level durability**:
```javascript
{
  w: "majority",           // Wait for majority of nodes to acknowledge
  j: true,                 // Wait for journal sync
  wtimeout: 5000          // Timeout after 5 seconds
}
```

**Reason**: Ensures data durability across replica set, critical for blog content

### Connection String Patterns

#### Standard Connection String (Replica Set)

```bash
# Application backend should use this format
mongodb://blogapp_api_user:<password>@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&readPreference=primaryPreferred&w=majority
```

**Key Components**:
- **Hosts**: Both replica set members (comma-separated)
- **Database**: `blogapp`
- **Replica Set**: `blogapp-rs0` parameter enables automatic failover
- **Read Preference**: `primaryPreferred` for HA
- **Write Concern**: `w=majority` for durability

#### Connection String for Different Scenarios

**Administrative Access**:
```bash
# For database administration (use admin database)
mongodb://admin:<admin_password>@10.0.3.4:27017,10.0.3.5:27017/admin?replicaSet=blogapp-rs0
```

**Direct Connection to Specific Node** (troubleshooting only):
```bash
# Connect to primary directly (bypass replica set)
mongodb://admin:<admin_password>@10.0.3.4:27017/blogapp
```

**Environment Variable Pattern**:
```bash
# In backend .env file
MONGODB_URI=mongodb://blogapp_api_user:${MONGODB_PASSWORD}@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&readPreference=primaryPreferred&w=majority
MONGODB_DATABASE=blogapp
```

### Failover Behavior

#### Automatic Failover

**Scenario: Primary Node Fails**
1. Secondary detects primary unavailable (heartbeat timeout: 10 seconds)
2. **MANUAL INTERVENTION REQUIRED** (2-node limitation)
3. Administrator must reconfigure replica set or force secondary to primary
4. Application reconnects automatically via replica set connection string

**Workshop Learning Objective**: 
- Students observe 2-node limitation (quorum requires majority)
- Demonstrates importance of 3+ node deployments
- Practice manual failover procedures (Day 2, Step 12)

#### Election Process

With 2 nodes, automatic election **cannot occur** without manual intervention:
- Requires majority (2/2 nodes)
- If primary fails, 1 surviving node cannot reach majority
- Workaround: `rs.reconfig()` with `force: true` flag

**Production Recommendation** (documented in workshop):
- Minimum 3 nodes for automatic failover
- Or use PSA architecture: 2 data nodes + 1 arbiter (lightweight voter)

### MongoDB Configuration

#### mongod.conf Settings

```yaml
# /etc/mongod.conf on both DB VMs

# Network settings
net:
  port: 27017                    # Standard MongoDB port
  bindIp: 0.0.0.0                # Bind to all interfaces (NSG protects)
  
# Storage settings
storage:
  dbPath: /data/mongodb          # Data directory on Premium SSD disk
  journal:
    enabled: true                # Enable journaling for durability
  wiredTiger:
    engineConfig:
      cacheSizeGB: 8             # 50% of 16GB RAM
      
# Replication settings
replication:
  replSetName: blogapp-rs0       # Replica set name
  oplogSizeMB: 2048              # 2GB oplog (sufficient for workshop)

# Security settings
security:
  authorization: enabled         # Require authentication
  
# Operation profiling (for workshop learning)
operationProfiling:
  mode: slowOp
  slowOpThresholdMs: 100         # Log queries slower than 100ms
  
# Logging
systemLog:
  destination: file
  path: /var/log/mongodb/mongod.log
  logAppend: true
  verbosity: 0
```

---

## Database Schema Design

### Database: `blogapp`

Collections: `users`, `posts`, `comments`, `sessions`

### Schema Design Philosophy

**Approach**: Hybrid (embedded + referenced)
- **Embed**: Comments within posts (common access pattern, small size)
- **Reference**: Authors/users (avoid duplication, profile updates)
- **Reasoning**: Optimized for read-heavy blog workload, balances query performance and update complexity

**Comparison with AWS**:
- Unlike DynamoDB (key-value), MongoDB supports flexible schemas
- Unlike DocumentDB (managed), requires manual replica set management
- Similar to self-managed MongoDB on EC2, but with Azure-specific HA patterns

---

### Collection: `users`

**Purpose**: Store user profile information from Microsoft Entra ID

#### Schema Definition

```typescript
interface User {
  _id: ObjectId;                    // MongoDB auto-generated ID
  entraUserId: string;              // Microsoft Entra ID user object ID (unique)
  email: string;                    // Email from Entra ID
  displayName: string;              // Display name from Entra ID
  givenName?: string;               // First name (optional)
  surname?: string;                 // Last name (optional)
  profilePicture?: string;          // URL to profile picture (Blob Storage or Entra ID)
  bio?: string;                     // User biography (max 500 chars)
  createdAt: Date;                  // Account creation timestamp
  updatedAt: Date;                  // Last profile update timestamp
  lastLoginAt: Date;                // Last login timestamp
  isActive: boolean;                // Account status (true = active)
  role: 'user' | 'admin';           // User role (future RBAC)
}
```

#### Field Definitions

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `_id` | ObjectId | Yes (auto) | - | MongoDB primary key |
| `entraUserId` | String | Yes | Unique index | Entra ID user object ID (e.g., "a1b2c3d4-...") |
| `email` | String | Yes | Email format, unique index | User email address |
| `displayName` | String | Yes | 1-100 chars | Full name or display name |
| `givenName` | String | No | 1-50 chars | First name |
| `surname` | String | No | 1-50 chars | Last name |
| `profilePicture` | String | No | URL format | Profile image URL |
| `bio` | String | No | Max 500 chars | User biography |
| `createdAt` | Date | Yes | - | ISO 8601 timestamp |
| `updatedAt` | Date | Yes | - | ISO 8601 timestamp |
| `lastLoginAt` | Date | Yes | - | ISO 8601 timestamp |
| `isActive` | Boolean | Yes | true/false | Account status |
| `role` | String | Yes | Enum: 'user', 'admin' | User role |

#### MongoDB Schema Validation

```javascript
db.createCollection("users", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["entraUserId", "email", "displayName", "createdAt", "updatedAt", "lastLoginAt", "isActive", "role"],
      properties: {
        entraUserId: {
          bsonType: "string",
          description: "Microsoft Entra ID user object ID - required"
        },
        email: {
          bsonType: "string",
          pattern: "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$",
          description: "Valid email address - required"
        },
        displayName: {
          bsonType: "string",
          minLength: 1,
          maxLength: 100,
          description: "Display name 1-100 characters - required"
        },
        givenName: {
          bsonType: "string",
          minLength: 1,
          maxLength: 50
        },
        surname: {
          bsonType: "string",
          minLength: 1,
          maxLength: 50
        },
        profilePicture: {
          bsonType: "string",
          pattern: "^https?://"
        },
        bio: {
          bsonType: "string",
          maxLength: 500
        },
        createdAt: {
          bsonType: "date"
        },
        updatedAt: {
          bsonType: "date"
        },
        lastLoginAt: {
          bsonType: "date"
        },
        isActive: {
          bsonType: "bool"
        },
        role: {
          enum: ["user", "admin"],
          description: "User role - required"
        }
      }
    }
  }
});
```

#### Indexes

```javascript
// Unique index on Entra ID user ID (primary lookup)
db.users.createIndex(
  { "entraUserId": 1 }, 
  { unique: true, name: "idx_entra_user_id" }
);

// Unique index on email (login lookup)
db.users.createIndex(
  { "email": 1 }, 
  { unique: true, name: "idx_email" }
);

// Index on isActive for filtering active users
db.users.createIndex(
  { "isActive": 1 }, 
  { name: "idx_is_active" }
);

// Compound index for active users sorted by creation date
db.users.createIndex(
  { "isActive": 1, "createdAt": -1 }, 
  { name: "idx_active_created" }
);
```

---

### Collection: `posts`

**Purpose**: Store blog post content with embedded comments

#### Schema Definition

```typescript
interface Post {
  _id: ObjectId;                    // MongoDB auto-generated ID
  title: string;                    // Post title
  slug: string;                     // URL-friendly slug (unique)
  content: string;                  // Post content (Markdown or HTML)
  excerpt: string;                  // Short excerpt (auto-generated from content)
  authorId: ObjectId;               // Reference to users._id
  authorName: string;               // Denormalized for performance (avoid join)
  tags: string[];                   // Array of tags (max 5)
  status: 'draft' | 'published';    // Publication status
  publishedAt?: Date;               // Publication timestamp (null if draft)
  createdAt: Date;                  // Creation timestamp
  updatedAt: Date;                  // Last update timestamp
  viewCount: number;                // View counter (incremented on read)
  comments: Comment[];              // Embedded comments array
  metadata: {
    readingTimeMinutes: number;     // Estimated reading time
    wordCount: number;              // Word count
    featuredImage?: string;         // URL to featured image (Blob Storage)
  };
}

interface Comment {
  _id: ObjectId;                    // Comment ID (embedded document)
  userId: ObjectId;                 // Reference to users._id
  userName: string;                 // Denormalized user name
  content: string;                  // Comment text
  createdAt: Date;                  // Comment timestamp
  updatedAt: Date;                  // Last edit timestamp
  isEdited: boolean;                // Flag if comment was edited
}
```

#### Field Definitions - Post

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `_id` | ObjectId | Yes (auto) | - | MongoDB primary key |
| `title` | String | Yes | 5-200 chars | Post title |
| `slug` | String | Yes | Unique, URL-safe | URL slug (e.g., "my-first-post") |
| `content` | String | Yes | Min 50 chars | Post content (Markdown/HTML) |
| `excerpt` | String | Yes | Max 300 chars | Short excerpt (first 150 chars) |
| `authorId` | ObjectId | Yes | Ref to users._id | Post author reference |
| `authorName` | String | Yes | 1-100 chars | Denormalized author name |
| `tags` | Array[String] | No | Max 5 items | Post tags/categories |
| `status` | String | Yes | Enum: 'draft', 'published' | Publication status |
| `publishedAt` | Date | No | Required if published | Publication timestamp |
| `createdAt` | Date | Yes | - | Creation timestamp |
| `updatedAt` | Date | Yes | - | Last update timestamp |
| `viewCount` | Number | Yes | Default 0 | View counter |
| `comments` | Array[Comment] | No | - | Embedded comments |
| `metadata.readingTimeMinutes` | Number | Yes | > 0 | Estimated reading time |
| `metadata.wordCount` | Number | Yes | >= 0 | Word count |
| `metadata.featuredImage` | String | No | URL format | Featured image URL |

#### Field Definitions - Comment (Embedded)

| Field | Type | Required | Validation | Description |
|-------|------|----------|------------|-------------|
| `_id` | ObjectId | Yes (auto) | - | Comment ID |
| `userId` | ObjectId | Yes | Ref to users._id | Comment author reference |
| `userName` | String | Yes | 1-100 chars | Denormalized user name |
| `content` | String | Yes | 1-1000 chars | Comment text |
| `createdAt` | Date | Yes | - | Comment creation timestamp |
| `updatedAt` | Date | Yes | - | Last edit timestamp |
| `isEdited` | Boolean | Yes | Default false | Edit flag |

#### MongoDB Schema Validation

```javascript
db.createCollection("posts", {
  validator: {
    $jsonSchema: {
      bsonType: "object",
      required: ["title", "slug", "content", "excerpt", "authorId", "authorName", "status", "createdAt", "updatedAt", "viewCount", "metadata"],
      properties: {
        title: {
          bsonType: "string",
          minLength: 5,
          maxLength: 200
        },
        slug: {
          bsonType: "string",
          pattern: "^[a-z0-9-]+$",
          description: "URL-friendly slug"
        },
        content: {
          bsonType: "string",
          minLength: 50
        },
        excerpt: {
          bsonType: "string",
          maxLength: 300
        },
        authorId: {
          bsonType: "objectId"
        },
        authorName: {
          bsonType: "string",
          minLength: 1,
          maxLength: 100
        },
        tags: {
          bsonType: "array",
          maxItems: 5,
          items: {
            bsonType: "string"
          }
        },
        status: {
          enum: ["draft", "published"]
        },
        publishedAt: {
          bsonType: ["date", "null"]
        },
        createdAt: {
          bsonType: "date"
        },
        updatedAt: {
          bsonType: "date"
        },
        viewCount: {
          bsonType: "int",
          minimum: 0
        },
        comments: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: ["userId", "userName", "content", "createdAt", "updatedAt", "isEdited"],
            properties: {
              userId: { bsonType: "objectId" },
              userName: { bsonType: "string" },
              content: { 
                bsonType: "string",
                minLength: 1,
                maxLength: 1000
              },
              createdAt: { bsonType: "date" },
              updatedAt: { bsonType: "date" },
              isEdited: { bsonType: "bool" }
            }
          }
        },
        metadata: {
          bsonType: "object",
          required: ["readingTimeMinutes", "wordCount"],
          properties: {
            readingTimeMinutes: {
              bsonType: "int",
              minimum: 1
            },
            wordCount: {
              bsonType: "int",
              minimum: 0
            },
            featuredImage: {
              bsonType: "string",
              pattern: "^https?://"
            }
          }
        }
      }
    }
  }
});
```

#### Indexes

```javascript
// Unique index on slug (URL lookup)
db.posts.createIndex(
  { "slug": 1 }, 
  { unique: true, name: "idx_slug" }
);

// Index on authorId (filter posts by author)
db.posts.createIndex(
  { "authorId": 1 }, 
  { name: "idx_author_id" }
);

// Compound index for published posts sorted by date (most common query)
db.posts.createIndex(
  { "status": 1, "publishedAt": -1 }, 
  { name: "idx_status_published_date" }
);

// Index on tags (filter by tag)
db.posts.createIndex(
  { "tags": 1 }, 
  { name: "idx_tags" }
);

// Text index for full-text search (title + content)
db.posts.createIndex(
  { 
    "title": "text", 
    "content": "text",
    "tags": "text"
  }, 
  { 
    name: "idx_text_search",
    weights: {
      title: 3,      // Title matches more important
      tags: 2,       // Tag matches medium importance
      content: 1     // Content matches least important
    }
  }
);

// Index on viewCount for popular posts
db.posts.createIndex(
  { "status": 1, "viewCount": -1 }, 
  { name: "idx_popular_posts" }
);
```

**Why Embed Comments?**
- Comments always displayed with posts (no separate query needed)
- Comment count typically small (< 100 per post for workshop)
- Simplifies data model for students
- Atomic updates (add comment + increment count in one operation)

**Trade-off**: Large comment counts (> 1000) would require separate collection. Document this limitation in workshop materials.

---

### Collection: `sessions` (Optional - Token Storage)

**Purpose**: Store session tokens if not using stateless JWT validation

**Note**: If backend validates JWT tokens stateless (recommended), this collection may not be needed. Include for completeness and potential session management requirements.

#### Schema Definition

```typescript
interface Session {
  _id: ObjectId;                    // MongoDB auto-generated ID
  sessionId: string;                // Unique session identifier
  userId: ObjectId;                 // Reference to users._id
  accessToken: string;              // Encrypted access token
  refreshToken?: string;            // Encrypted refresh token (if using refresh flow)
  expiresAt: Date;                  // Session expiration timestamp
  createdAt: Date;                  // Session creation timestamp
  lastActivityAt: Date;             // Last activity timestamp
  userAgent?: string;               // User agent string
  ipAddress?: string;               // IP address
}
```

#### Indexes

```javascript
// Unique index on sessionId
db.sessions.createIndex(
  { "sessionId": 1 }, 
  { unique: true, name: "idx_session_id" }
);

// Index on userId (lookup user sessions)
db.sessions.createIndex(
  { "userId": 1 }, 
  { name: "idx_user_id" }
);

// TTL index to auto-delete expired sessions
db.sessions.createIndex(
  { "expiresAt": 1 }, 
  { 
    expireAfterSeconds: 0,  // Delete when expiresAt time passes
    name: "idx_ttl_expires"
  }
);
```

**Design Decision**: 
- **Recommended**: Use stateless JWT validation (no session storage)
- **Alternative**: Use sessions collection for revocation, device tracking
- Workshop should demonstrate stateless approach first, mention sessions as enhancement

---

## Data Relationships

### Relationship Diagram

```
┌─────────────────┐
│     users       │
│  _id (PK)       │
│  entraUserId    │
│  email          │
│  displayName    │
└────────┬────────┘
         │
         │ 1:N (Reference)
         │
         ▼
┌─────────────────────────┐
│       posts             │
│  _id (PK)               │
│  authorId (FK) ────────►│
│  authorName (denorm)    │
│  content                │
│  comments: [            │◄─── Embedded documents
│    {                    │
│      userId (FK) ───────┤
│      userName (denorm)  │
│      content            │
│    }                    │
│  ]                      │
└─────────────────────────┘
```

### Relationship Patterns

#### 1. User → Posts (One-to-Many, Referenced)

**Approach**: Reference (store `authorId` in posts)
- **Reason**: Users can have many posts, avoid embedding large arrays in user document
- **Query Pattern**: `db.posts.find({ authorId: userId })`

**Denormalization**: Store `authorName` in posts
- **Reason**: Avoid join on every post list query
- **Trade-off**: If user changes name, must update all their posts
- **Mitigation**: Update operation when user profile changes

#### 2. User → Comments (One-to-Many, Embedded in Posts)

**Approach**: Reference via `userId` within embedded comment
- **Reason**: Comment belongs to both post (embedded) and user (referenced)
- **Query Pattern**: Comments queried with parent post

**Denormalization**: Store `userName` in comments
- **Reason**: Display commenter name without user lookup
- **Trade-off**: Same as posts, requires update if name changes

#### 3. Post → Comments (One-to-Many, Embedded)

**Approach**: Embed comments array in post document
- **Reason**: Comments always displayed with post
- **Limitation**: MongoDB 16MB document size limit
- **Estimate**: ~10,000 comments per post before hitting limit (unlikely in workshop)

**Alternative Pattern** (document for reference):
- Separate `comments` collection if comment volume high
- Store `postId` reference in comment documents
- Workshop can demonstrate both patterns

---

## Backup and Recovery Strategy

### Backup Approach: Dual Strategy

**Strategy 1: Azure Backup (VM-level)**
- **What**: Snapshot entire DB VM (OS + data disks)
- **Frequency**: Daily backups at 2:00 AM UTC
- **Retention**: 7 daily, 4 weekly, 3 monthly
- **RTO**: 1-2 hours (VM restore time)
- **RPO**: 24 hours (daily backup)
- **Pros**: Simple, full system recovery, Azure-native
- **Cons**: Coarse-grained, entire VM restore required

**Strategy 2: MongoDB Native Backup**
- **What**: `mongodump` to create BSON backups
- **Frequency**: Daily via cron job or GitHub Actions
- **Storage**: Azure Blob Storage (separate from VMs)
- **Retention**: 7 days
- **RTO**: 30 minutes (database restore only)
- **RPO**: 24 hours (daily backup)
- **Pros**: Fine-grained, faster restore, portable
- **Cons**: Requires scripting, separate storage cost

### Backup Procedures

#### Azure Backup Configuration

**Bicep/Portal Configuration**:
- Enable Azure Backup on both DB VMs
- Create Recovery Services Vault in same region
- Configure backup policy:
  - Daily backup at 2:00 AM UTC
  - Retention: 7 daily, 4 weekly, 3 monthly backups
  - Instant restore enabled (snapshot tier)

**Cost Consideration**:
- Backup storage: ~$0.10/GB/month
- Per 128GB data disk: ~$12.80/month
- For 20 students: ~$256/month (budgeting)

#### MongoDB Native Backup Script

```bash
#!/bin/bash
# /usr/local/bin/mongodb-backup.sh
# Runs daily via cron: 0 2 * * * /usr/local/bin/mongodb-backup.sh

DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/backup/mongodb"
BACKUP_NAME="blogapp-backup-$DATE"
STORAGE_ACCOUNT="<storage_account_name>"
CONTAINER="mongodb-backups"

# Create backup directory
mkdir -p $BACKUP_DIR

# Run mongodump (all databases)
mongodump --host localhost:27017 \
          --username admin \
          --password $MONGODB_ADMIN_PASSWORD \
          --authenticationDatabase admin \
          --out $BACKUP_DIR/$BACKUP_NAME \
          --gzip

# Compress backup
cd $BACKUP_DIR
tar -czf $BACKUP_NAME.tar.gz $BACKUP_NAME/
rm -rf $BACKUP_NAME/

# Upload to Azure Blob Storage using Azure CLI
az storage blob upload \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER \
  --name $BACKUP_NAME.tar.gz \
  --file $BACKUP_DIR/$BACKUP_NAME.tar.gz \
  --auth-mode login

# Clean up local backup (keep last 2 days locally)
find $BACKUP_DIR -name "*.tar.gz" -mtime +2 -delete

echo "Backup completed: $BACKUP_NAME.tar.gz"
```

#### Restore Procedures

**Restore from Azure Backup** (VM-level):
1. Navigate to Recovery Services Vault in Azure Portal
2. Select DB VM recovery point
3. Choose restore type (Create new VM or Replace existing)
4. Restore VM (15-30 minutes)
5. Update DNS/connection strings if new VM created
6. Verify replica set status: `rs.status()`

**Restore from MongoDB Native Backup**:
```bash
# Download backup from Blob Storage
az storage blob download \
  --account-name <storage_account> \
  --container-name mongodb-backups \
  --name blogapp-backup-20250201-020000.tar.gz \
  --file /tmp/restore.tar.gz

# Extract backup
cd /tmp
tar -xzf restore.tar.gz

# Stop MongoDB (if restoring in place)
sudo systemctl stop mongod

# Restore using mongorestore
mongorestore --host localhost:27017 \
             --username admin \
             --password $MONGODB_ADMIN_PASSWORD \
             --authenticationDatabase admin \
             --gzip \
             --drop \
             /tmp/blogapp-backup-20250201-020000/

# Start MongoDB
sudo systemctl start mongod

# Verify data
mongo --host localhost:27017 -u admin -p $MONGODB_ADMIN_PASSWORD --authenticationDatabase admin
> use blogapp
> db.posts.countDocuments()
```

### Recovery Targets

| Scenario | RTO (Recovery Time Objective) | RPO (Recovery Point Objective) | Method |
|----------|-------------------------------|--------------------------------|--------|
| Database corruption | 30 minutes | 24 hours | MongoDB native restore |
| Accidental data deletion | 30 minutes | 24 hours | MongoDB native restore |
| VM failure (single node) | 0 minutes (auto-failover*) | 0 minutes | Replica set failover |
| Complete region failure | 2-4 hours | 24 hours | Azure Site Recovery (DR) |
| Disaster (both VMs lost) | 1-2 hours | 24 hours | Azure Backup restore |

*Automatic failover limited with 2-node setup (requires manual intervention)

---

## Initial Data Seeding Strategy

### Seed Data Purpose

**Educational Value**:
- Provide sample data for immediate workshop testing
- Demonstrate MongoDB query patterns
- Enable frontend development/testing without manual data entry

### Seed Data Contents

**Users** (5 sample users):
```javascript
[
  {
    entraUserId: "sample-user-1",
    email: "alice.workshop@example.com",
    displayName: "Alice Workshop",
    role: "admin",
    isActive: true,
    createdAt: new Date("2025-01-01"),
    updatedAt: new Date("2025-01-01"),
    lastLoginAt: new Date("2025-12-01")
  },
  {
    entraUserId: "sample-user-2",
    email: "bob.workshop@example.com",
    displayName: "Bob Student",
    role: "user",
    isActive: true,
    createdAt: new Date("2025-01-15"),
    updatedAt: new Date("2025-01-15"),
    lastLoginAt: new Date("2025-12-01")
  }
  // ... 3 more users
]
```

**Posts** (10 sample posts):
```javascript
[
  {
    title: "Getting Started with Azure IaaS",
    slug: "getting-started-azure-iaas",
    content: "Learn about Azure Virtual Machines, VNets, and NSGs...",
    excerpt: "An introduction to Azure IaaS services for AWS professionals.",
    authorId: ObjectId("alice-id"),
    authorName: "Alice Workshop",
    tags: ["azure", "iaas", "beginner"],
    status: "published",
    publishedAt: new Date("2025-01-10"),
    viewCount: 42,
    comments: [
      {
        userId: ObjectId("bob-id"),
        userName: "Bob Student",
        content: "Great introduction! Very helpful for AWS users.",
        createdAt: new Date("2025-01-11"),
        updatedAt: new Date("2025-01-11"),
        isEdited: false
      }
    ],
    metadata: {
      readingTimeMinutes: 5,
      wordCount: 1200
    }
  }
  // ... 9 more posts
]
```

### Seed Script

**Location**: `materials/backend/scripts/seed-database.ts`

```typescript
// seed-database.ts
import { MongoClient, ObjectId } from 'mongodb';

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/blogapp';

async function seedDatabase() {
  const client = new MongoClient(MONGODB_URI);
  
  try {
    await client.connect();
    const db = client.db('blogapp');
    
    // Clear existing data (development only!)
    await db.collection('users').deleteMany({});
    await db.collection('posts').deleteMany({});
    
    // Seed users
    const users = [...]; // Sample user data
    const userResult = await db.collection('users').insertMany(users);
    console.log(`Inserted ${userResult.insertedCount} users`);
    
    // Seed posts (using actual user IDs from above)
    const posts = [...]; // Sample post data
    const postResult = await db.collection('posts').insertMany(posts);
    console.log(`Inserted ${postResult.insertedCount} posts`);
    
    console.log('Database seeded successfully!');
  } catch (error) {
    console.error('Error seeding database:', error);
    throw error;
  } finally {
    await client.close();
  }
}

seedDatabase();
```

**Execution**:
```bash
# Run during Day 1 Step 2 (Configure Database)
cd /opt/blogapp/backend
npm run seed

# Or via GitHub Actions workflow
# Triggered after MongoDB replica set initialization
```

---

## Security Configuration

### Authentication and Authorization

#### User Roles

**MongoDB Admin User**:
```javascript
// Created during MongoDB installation
db.createUser({
  user: "admin",
  pwd: "<strong_admin_password>",  // From Azure Key Vault
  roles: [
    { role: "root", db: "admin" }
  ]
});
```

**Application User** (least privilege):
```javascript
// Created for backend API access
use blogapp;
db.createUser({
  user: "blogapp_api_user",
  pwd: "<strong_api_password>",    // From Azure Key Vault or GitHub Secret
  roles: [
    { role: "readWrite", db: "blogapp" }
  ]
});
```

**Backup User** (read-only + backup):
```javascript
use admin;
db.createUser({
  user: "backup_user",
  pwd: "<strong_backup_password>",
  roles: [
    { role: "backup", db: "admin" },
    { role: "read", db: "blogapp" }
  ]
});
```

### Network Security

**MongoDB Bind Configuration**:
- Bind to all interfaces: `0.0.0.0` (NSG provides security)
- **Why**: Allows replica set members to communicate across subnets
- **Protection**: NSG rules restrict access to app tier subnet only

**NSG Rules** (from AzureArchitectureDesign.md):
- Allow MongoDB port (27017) from App tier subnet (10.0.2.0/24) only
- Deny all other inbound traffic
- Allow SSH (22) from Azure Bastion subnet only

### Encryption

**In-Transit Encryption** (TLS/SSL):
- **Recommendation**: Enable TLS for production
- **Workshop**: Optional (time constraint)
- **Configuration**: Generate self-signed certs or use Let's Encrypt

```yaml
# mongod.conf (if TLS enabled)
net:
  ssl:
    mode: requireSSL
    PEMKeyFile: /etc/ssl/mongodb/mongodb.pem
    CAFile: /etc/ssl/mongodb/ca.pem
```

**At-Rest Encryption**:
- **Azure Managed Disks**: Encrypted by default (Azure Storage Service Encryption)
- **MongoDB**: WiredTiger encryption at rest (Enterprise Edition only)
- **Workshop**: Rely on Azure disk encryption (sufficient for learning)

### Secret Management

**Password Storage**:
- **Recommended**: Azure Key Vault
- **Alternative**: GitHub Secrets (for workshop simplicity)
- **Never**: Hardcode in scripts or configuration files

**Environment Variable Pattern**:
```bash
# /etc/environment or systemd service file
MONGODB_ADMIN_PASSWORD=<from_key_vault>
MONGODB_API_PASSWORD=<from_key_vault>
```

---

## Monitoring and Health Checks

### MongoDB Metrics to Monitor

**Replica Set Health**:
- `rs.status()` - Replica set member status
- `rs.conf()` - Replica set configuration
- Replication lag (seconds behind primary)
- Oplog window (hours of oplog available)

**Performance Metrics**:
- Query operations per second (reads, writes)
- Slow queries (> 100ms)
- Connection count (active connections)
- Memory usage (WiredTiger cache utilization)
- Disk I/O (Premium SSD performance)

**Database Metrics**:
- Database size (MB/GB)
- Collection counts (documents per collection)
- Index size (MB/GB)
- Index usage statistics

### Health Check Endpoints

**MongoDB Native Health Check**:
```javascript
// Check replica set status
rs.status()

// Expected output:
{
  "set": "blogapp-rs0",
  "members": [
    {
      "name": "10.0.3.4:27017",
      "health": 1,
      "state": 1,  // PRIMARY
      "stateStr": "PRIMARY"
    },
    {
      "name": "10.0.3.5:27017",
      "health": 1,
      "state": 2,  // SECONDARY
      "stateStr": "SECONDARY"
    }
  ],
  "ok": 1
}
```

**Backend API Health Check** (for load balancer probe):
```typescript
// GET /api/health
app.get('/api/health', async (req, res) => {
  try {
    // Ping MongoDB
    await client.db('admin').command({ ping: 1 });
    
    res.status(200).json({
      status: 'healthy',
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      database: 'disconnected',
      error: error.message
    });
  }
});
```

### Azure Monitor Integration

**Log Collection**:
- MongoDB logs → Azure Monitor Agent → Log Analytics
- Query slow queries, errors, warnings

**Sample Log Analytics Query**:
```kql
Syslog
| where Facility == "local0"  // MongoDB syslog facility
| where SyslogMessage contains "slow query"
| project TimeGenerated, Computer, SyslogMessage
| order by TimeGenerated desc
```

**Alert Rules**:
- Replica set member down (state != PRIMARY/SECONDARY)
- Replication lag > 60 seconds
- Disk space > 80% utilization
- Connection count > 1000 (anomaly detection)

---

## Performance Optimization

### Indexing Strategy

**Best Practices**:
1. **Create indexes for all queries** - Avoid collection scans
2. **Use compound indexes** - Multi-field queries (status + date)
3. **Monitor index usage** - Remove unused indexes
4. **Limit index count** - Each index slows writes

**Index Analysis**:
```javascript
// Explain query plan
db.posts.find({ status: "published" }).sort({ publishedAt: -1 }).explain("executionStats");

// Check index usage
db.posts.aggregate([
  { $indexStats: {} }
]);
```

### Query Optimization

**Common Patterns**:
```javascript
// Good: Uses index on status + publishedAt
db.posts.find({ status: "published" }).sort({ publishedAt: -1 }).limit(10);

// Good: Uses unique index on slug
db.posts.findOne({ slug: "my-post-slug" });

// Bad: Full collection scan (no index on viewCount alone)
db.posts.find({}).sort({ viewCount: -1 });  // Should use compound index

// Good: Uses text index
db.posts.find({ $text: { $search: "azure iaas" } });
```

### Connection Pooling

**Backend Configuration** (Mongoose):
```typescript
// Connection pool settings
mongoose.connect(process.env.MONGODB_URI, {
  maxPoolSize: 50,          // Max connections in pool
  minPoolSize: 10,          // Min connections maintained
  serverSelectionTimeoutMS: 5000,  // Timeout for selecting server
  socketTimeoutMS: 45000,   // Timeout for socket operations
  family: 4                 // Use IPv4
});
```

**Rationale**:
- 2 app tier VMs × 50 connections = 100 total connections
- MongoDB can handle 1000+ connections (sufficient for workshop)

### Memory Configuration

**WiredTiger Cache**:
- Default: 50% of RAM (8GB for 16GB VM)
- Sufficient for workshop dataset (< 1GB)
- Monitor cache hit ratio (should be > 95%)

**Oplog Size**:
- Configured: 2GB (2048 MB)
- Workshop dataset: Oplog provides ~24 hours of operations
- Production: Size based on write rate and maintenance window

---

## Comparison with AWS Database Services

### MongoDB on Azure VMs vs AWS Alternatives

| Feature | MongoDB on Azure VMs (Workshop) | AWS DocumentDB | AWS DynamoDB |
|---------|--------------------------------|----------------|--------------|
| **Type** | Self-managed MongoDB | Managed MongoDB-compatible | Managed NoSQL key-value |
| **HA Setup** | Manual replica set config | Automatic (6 replicas across 3 AZs) | Automatic (3 AZ replication) |
| **Failover** | Manual (2-node) or auto (3+ nodes) | Automatic (< 30s) | Automatic (instant) |
| **Backup** | Manual (mongodump + Azure Backup) | Automated continuous backups | Automated continuous backups |
| **Scaling** | Vertical (resize VM) | Vertical (instance size) | Horizontal (automatic) |
| **Operational Overhead** | High (patching, monitoring, backups) | Low (AWS manages) | Very Low (fully managed) |
| **Cost** | VM + Disk + Backup | Higher (managed service premium) | Pay-per-request (can be lower) |
| **MongoDB Compatibility** | 100% (native MongoDB) | ~95% (some features missing) | N/A (different API) |
| **Learning Value** | High (understand HA, DR, operations) | Medium (managed abstracts details) | Medium (different paradigm) |

**Workshop Educational Value**:
- **Why self-managed MongoDB**: Teaches operational concepts (replica sets, failover, backups)
- **AWS DocumentDB equivalent**: Managed MongoDB-compatible service (easier, but hides details)
- **DynamoDB alternative**: NoSQL key-value store (different data model, simpler for key-value workloads)

**Production Recommendation** (include in workshop docs):
- **Small/Medium apps**: Consider Azure Cosmos DB for MongoDB (managed service, lower ops overhead)
- **Large/Complex apps**: Self-managed MongoDB for full feature compatibility and control
- **Key-value workloads**: Azure Cosmos DB (native) or Table Storage for cost optimization

---

## Migration Strategy

### Schema Evolution

**Approach**: No formal migrations (MongoDB schema-less)
- **Reason**: MongoDB allows flexible schemas, no ALTER TABLE equivalent
- **Strategy**: Application-level schema validation and versioning

**Best Practices**:
1. **Add fields**: Graceful degradation (check field existence)
2. **Remove fields**: Leave old data, app ignores legacy fields
3. **Rename fields**: Dual writes during transition, then cleanup
4. **Change types**: Write migration script, run during maintenance window

**Example Migration** (add `status` field to existing posts):
```javascript
// Migration script: add-post-status.js
db.posts.updateMany(
  { status: { $exists: false } },  // Posts without status field
  { $set: { status: "published" } } // Default to published
);
```

### Data Migration (Future Cloud Migration)

**Scenario**: Migrate to Azure Cosmos DB for MongoDB API

**Approach**:
1. **Dual-write**: Write to both MongoDB VMs and Cosmos DB temporarily
2. **Sync existing data**: Use `mongodump` + `mongorestore` to Cosmos DB
3. **Cutover**: Switch read traffic to Cosmos DB
4. **Decommission**: Remove MongoDB VMs after validation

**Workshop Note**: Mention this path for students considering PaaS future

---

## Troubleshooting Guide

### Common Issues

#### Issue: Replica Set Member Not Syncing

**Symptoms**:
- Secondary shows `RECOVERING` state
- Replication lag increasing

**Diagnosis**:
```javascript
rs.status()  // Check member states
rs.printReplicationInfo()  // Check oplog
```

**Solutions**:
1. Check network connectivity between nodes
2. Verify oplog size (may need to increase)
3. Resync secondary: `rs.reconfig()` or full resync

#### Issue: Connection Refused

**Symptoms**:
- Backend cannot connect to MongoDB
- Error: `MongoNetworkError: connect ECONNREFUSED`

**Diagnosis**:
```bash
# Check MongoDB is running
sudo systemctl status mongod

# Check MongoDB is listening on correct port
sudo netstat -tuln | grep 27017

# Check NSG rules allow app tier traffic
az network nsg rule list --nsg-name db-nsg --resource-group <rg>
```

**Solutions**:
1. Start MongoDB: `sudo systemctl start mongod`
2. Verify `bindIp` in `mongod.conf` (should be `0.0.0.0`)
3. Check NSG rules allow port 27017 from app subnet

#### Issue: Slow Queries

**Symptoms**:
- API responses slow (> 1s)
- MongoDB logs show slow queries

**Diagnosis**:
```javascript
// Find slow queries in profiling data
db.system.profile.find({ millis: { $gt: 100 } }).sort({ millis: -1 });

// Explain specific query
db.posts.find({ status: "published" }).explain("executionStats");
```

**Solutions**:
1. Create appropriate indexes (see Index section)
2. Use projection to limit returned fields
3. Implement pagination (limit + skip)
4. Monitor WiredTiger cache usage

#### Issue: Authentication Failed

**Symptoms**:
- Error: `Authentication failed`
- Cannot connect to MongoDB

**Diagnosis**:
```bash
# Try connecting with admin user
mongo --host localhost:27017 -u admin -p --authenticationDatabase admin

# Check user exists
use blogapp
db.getUsers()
```

**Solutions**:
1. Verify password is correct (check environment variables)
2. Verify user exists in correct database
3. Create user if missing (see Security Configuration)

---

## Workshop Integration

### Day 1 Step 2: Configure Database

**Student Actions**:
1. SSH to DB VM via Azure Bastion
2. Verify MongoDB installed and running
3. Initialize replica set using provided script
4. Create admin and application users
5. Verify replica set status: `rs.status()`
6. Run seed data script
7. Verify data: `db.posts.countDocuments()`

**Expected Time**: 20-25 minutes

**Success Criteria**:
- Replica set initialized with 2 members
- Both members showing healthy status (PRIMARY + SECONDARY)
- Application user created with readWrite role
- Seed data loaded (5 users, 10 posts)
- Connection from app tier VM successful

### Day 2 Step 12: Test DB Tier HA

**Student Actions**:
1. Note current primary node
2. Stop MongoDB on primary: `sudo systemctl stop mongod`
3. Observe application behavior (should show errors or timeouts)
4. Manually reconfigure replica set (2-node limitation)
5. Verify application resumes (may require app restart)
6. Start stopped MongoDB node
7. Verify it rejoins as secondary

**Expected Time**: 15-20 minutes

**Learning Objectives**:
- Experience manual failover with 2-node setup
- Understand quorum requirements (2/2 cannot auto-elect)
- Practice recovery procedures
- Compare with 3+ node automatic failover (documented)

---

## Appendix

### A. MongoDB Version Selection

**Recommended**: MongoDB Community Edition 7.0.x
- **Reason**: Latest stable, long-term support
- **Compatibility**: Works with Mongoose 8.x, MongoDB Node.js Driver 6.x
- **Features**: Improved query performance, better replication

**Alternative**: MongoDB 6.0.x
- **Reason**: More mature, widely deployed
- **Trade-off**: Slightly older features

### B. Useful MongoDB Commands

```javascript
// Check replica set status
rs.status()

// Check replica set configuration
rs.conf()

// Check replication lag
rs.printSecondaryReplicationInfo()

// Check oplog size and window
rs.printReplicationInfo()

// Database statistics
db.stats()

// Collection statistics
db.posts.stats()

// Current operations
db.currentOp()

// Kill long-running operation
db.killOp(<opid>)
```

### C. Connection String Examples

**Replica Set with All Options**:
```
mongodb://user:password@10.0.3.4:27017,10.0.3.5:27017/blogapp?replicaSet=blogapp-rs0&readPreference=primaryPreferred&w=majority&retryWrites=true&maxPoolSize=50
```

**Admin Connection**:
```
mongodb://admin:password@10.0.3.4:27017/admin?replicaSet=blogapp-rs0
```

**Direct Connection (Troubleshooting)**:
```
mongodb://user:password@10.0.3.4:27017/blogapp
```

### D. Reference Documentation

**Official MongoDB Docs**:
- [Replica Sets](https://docs.mongodb.com/manual/replication/)
- [Replica Set Configuration](https://docs.mongodb.com/manual/reference/replica-configuration/)
- [Backup and Restore](https://docs.mongodb.com/manual/core/backups/)
- [Indexes](https://docs.mongodb.com/manual/indexes/)
- [Schema Validation](https://docs.mongodb.com/manual/core/schema-validation/)

**Azure Documentation**:
- [Azure Backup for VMs](https://learn.microsoft.com/azure/backup/backup-azure-vms-introduction)
- [Azure Monitor Agent](https://learn.microsoft.com/azure/azure-monitor/agents/agents-overview)
- [Availability Zones](https://learn.microsoft.com/azure/reliability/availability-zones-overview)

**Mongoose (Backend Integration)**:
- [Mongoose Documentation](https://mongoosejs.com/docs/guide.html)
- [Mongoose Schema Validation](https://mongoosejs.com/docs/validation.html)

---

## Document Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-01 | Database Administrator Agent | Initial database design specification |

---

**End of Database Design Specification**
