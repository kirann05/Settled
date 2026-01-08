#!/bin/bash

# Deploy Firestore Security Rules
# This script fixes multiple permissions errors:
# 1. Bills collection - participants can now view bills created by others
# 2. TransactionContacts subcollection - users can access their contact data

echo "🔥 Deploying Firestore Security Rules..."
echo "📍 Project: settledapp-bd116"
echo "📁 Working Directory: $(pwd)"

# Navigate to Firebase directory
cd /Users/shivagandluri/Documents/SettledApp/infrastructure/firebase

echo "📋 Deploying rules from: $(pwd)"
echo "🔧 Rules file: firestore.rules"

echo "🔍 Fixes included:"
echo "   ✅ Users collection: Allow all authenticated users to read for lookups"
echo "   ✅ Bills collection: Allow deletion metadata fields in update (deletedBy, deletedByDisplayName, deletedAt, version, operationId)"
echo "   ✅ BillActivities subcollection: Bill creators can write to all participants' history"
echo "   ✅ BillActivities subcollection: Users can read their own activity history"

# Deploy only Firestore rules
firebase deploy --only firestore:rules --project settledapp-bd116

if [ $? -eq 0 ]; then
    echo "✅ Firestore rules deployed successfully!"
    echo "🎯 Fixes applied:"
    echo "   📋 Users can read other users' data for lookups (deletion activity creation)"
    echo "   🗑️ Deletion metadata fields are now allowed in bill updates"
    echo "   📜 Bill activity history tracking enabled (History tab deletion activities fix)"
    echo "   ✅ Permission errors resolved for deletion activity creation"
else
    echo "❌ Deployment failed!"
    echo "🔧 Ensure you're authenticated: firebase login"
    echo "📋 Ensure project exists: firebase projects:list"
    echo "🚨 Check Firebase Console for detailed error messages"
fi