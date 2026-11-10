module.exports = {
  apps: [{
    name: "cinezoo-backend",
    cwd: "backend",
    script: "bin/rails",
    args: "server",
    interpreter: "none",
    env: {
      RAILS_ENV: "production",
      RAILS_LOG_TO_STDOUT: "1",
    },
  }]
};
