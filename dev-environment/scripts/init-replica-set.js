// Initialize MongoDB Replica Set for Local Development
// Run this script after starting containers:
// docker exec -it blogapp-mongo-primary mongosh /scripts/init-replica-set.js

rs.initiate({
  _id: "blogapp-rs0",
  version: 1,
  members: [
    {
      _id: 0,
      host: "mongo-primary:27017",
      priority: 2,
      votes: 1
    },
    {
      _id: 1,
      host: "mongo-secondary:27017",
      priority: 1,
      votes: 1
    }
  ]
});

// Wait for replica set to initialize
sleep(2000);

// Check replica set status
rs.status();

print("\n✅ Replica set initialized successfully!");
print("Primary: mongo-primary:27017");
print("Secondary: mongo-secondary:27017");
print("\nConnection string for applications:");
print("mongodb://localhost:27017,localhost:27018/blogapp?replicaSet=blogapp-rs0");
print("\nNote: Authentication disabled for local development simplicity.");
print("In production (Azure VMs), use proper authentication with passwords from Key Vault.");
