const https = require('https');

function get(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'User-Agent': 'Node.js' } }, (res) => {
      let data = '';
      if (res.statusCode === 301 || res.statusCode === 302) {
        return resolve(get(res.headers.location));
      }
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

async function run() {
  try {
    const runsStr = await get('https://api.github.com/repos/habiburportfolio/tutor-manager-app/actions/runs');
    console.log('API Response:', runsStr.substring(0, 500));
  } catch (err) {
    console.error(err);
  }
}

run();
