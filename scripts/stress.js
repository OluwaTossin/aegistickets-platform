import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

// Stress test configuration
export const options = {
  stages: [
    { duration: '1m', target: 50 },   // Ramp up to 50 users
    { duration: '3m', target: 100 },  // Ramp up to 100 users
    { duration: '2m', target: 100 },  // Stay at 100 users
    { duration: '1m', target: 0 },    // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<1200'], // More lenient threshold for stress
    http_req_failed: ['rate<0.05'],    // Allow up to 5% failures under stress
  },
};

const BASE_URL = __ENV.HOST || 'http://localhost';

export default function () {
  // Simulate heavy traffic patterns
  const endpoints = [
    `/api/events`,
    `/api/events/1`,
    `/api/events/2`,
    `/api/events/3`,
  ];

  // Random endpoint selection
  const endpoint = endpoints[Math.floor(Math.random() * endpoints.length)];
  
  const res = http.get(`${BASE_URL}${endpoint}`);
  check(res, {
    'status is 2xx': (r) => r.status >= 200 && r.status < 300,
  }) || errorRate.add(1);

  // Add to basket with some probability
  if (Math.random() < 0.3) {
    const basketPayload = JSON.stringify({
      event_id: Math.floor(Math.random() * 3) + 1,
      quantity: Math.floor(Math.random() * 5) + 1,
    });
    
    http.post(`${BASE_URL}/api/basket`, basketPayload, {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  sleep(Math.random() * 2); // Random sleep 0-2s
}
