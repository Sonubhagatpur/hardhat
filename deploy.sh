echo "Deploying to Binance Smart Chain..."
npx hardhat run scripts/deploy.js --network bscTestnet

echo "Deploying to Sepolia..."
npx hardhat run scripts/deploy.js --network sepoliaTestnet
 
echo "Deploying to Polygon..."
npx hardhat run scripts/deploy.js --network polygon

echo "Deployment completed!"