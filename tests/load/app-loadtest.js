// k6 Load Testing Configuration
// Run with: k6 run tests/load/app-loadtest.js
// Run with cloud: k6 cloud tests/load/app-loadtest.js
// Run with summary: k6 run --summary-export=results.json tests/load/app-loadtest.js

import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Trend, Rate, Counter } from 'k6/metrics';

// Custom metrics
const myTrend = new Trend('waiting_time');
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  // Test stages: ramp up, sustain, ramp down
  stages: [
    { duration: '30s', target: 20 },   // Ramp up to 20 users
    { duration: '1m', target: 20 },    // Stay at 20 users
    { duration: '30s', target: 50 },   // Spike to 50 users
    { duration: '1m', target: 50 },    // Stay at 50 users
    { duration: '30s', target: 0 },    // Ramp down to 0
  ],

  // Thresholds (fail the test if breached)
  thresholds: {
    http_req_duration: ['p(95)<500'],   // 95% of requests must complete below 500ms
    http_req_failed: ['rate<0.01'],     // Error rate must be below 1%
    errors: ['rate<0.05'],              // Custom error rate below 5%
    http_req_duration: ['p(99)<1000'],  // 99% of requests below 1s
  },

  // Summary trends
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)', 'count'],
};

// Setup: runs once before the test
export function setup() {
  console.log('Starting load test...');
  return { startTime: new Date() };
}

// Main test function: runs for each VU iteration
export default function (data) {
  group('Health Check', function () {
    const res = http.get('http://localhost:3000/health');

    const checkRes = check(res, {
      'health status is 200': (r) => r.status === 200,
      'health response time < 200ms': (r) => r.timings.duration < 200,
      'health body contains status': (r) => r.body.includes('status'),
    });

    errorRate.add(!checkRes);
    myTrend.add(res.timings.waiting);
  });

  group('API Endpoints', function () {
    const res = http.get('http://localhost:3000/api/v1/status');

    check(res, {
      'api status is 200': (r) => r.status === 200,
      'api response time < 300ms': (r) => r.timings.duration < 300,
    });
  });

  // Simulate realistic user think time
  sleep(Math.random() * 2 + 1);
}

// Teardown: runs once after the test
export function teardown(data) {
  const endTime = new Date();
  const duration = (endTime - data.startTime) / 1000;
  console.log(`Load test completed. Duration: ${duration}s`);
}
