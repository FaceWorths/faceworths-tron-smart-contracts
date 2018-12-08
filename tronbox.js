module.exports = {
  networks: {
    development: {
      // For trontools/quickstart docker image
      privateKey: '8fc3f1be65ae8e8d85dd2fab28f8c8ac5f779656e50844990fd7e04b785ad3b5',
      consume_user_resource_percent: 30,
      fee_limit: 1e9,
      fullHost: "http://127.0.0.1:9090",
      network_id: "*"
    },
    shasta: {
      privateKey: process.env.PK,
      consume_user_resource_percent: 30,
      fee_limit: 1e9,
      fullHost: "https://api.shasta.trongrid.io",
      network_id: "*"
    },
    mainnet: {
      /*
        Don't put your private key here:
        Create a .env file (it must be gitignored) containing something like
        export PK=4E7FECCB71207B867C495B51A9758B104B1D4422088A87F4978BE64636656243
        Then, run the migration with:
        source .env && tronbox migrate --network mainnet
      */
      privateKey: process.env.PK,
      consume_user_resource_percent: 30,
      fee_limit: 1e9,
      fullHost: "https://api.trongrid.io",
      network_id: "*"
    }
  }
};
