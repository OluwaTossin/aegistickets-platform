import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '30s', target: 10 },  // Ramp up to 10 users
    { duration: '1m', target: 10 },   // Stay at 10 users
    { duration: '30s', target: 0 },   // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<800'], // 95% of requests must complete below 800ms
    http_req_failed: ['rate<0.01'],   // Error rate must be less than 1%
    errors: ['rate<0.01'],
  },
};

// Get target host from environment variable
const BASE_URL = __ENV.HOST || 'http://localhost';

export default function () {
  // Test 1: Get all events
  let res = http.get(`${BASE_URL}/api/events`);
  check(res, {
    'events list status is 200': (r) => r.status === 200,
    'events list has data': (r) => {
      const body = JSON.parse(r.body);
      return body.events && body.events.length > 0;
    },
  }) || errorRate.add(1);

  sleep(1);

  // Test 2: Get single event
  res = http.get(`${BASE_URL}/api/events/1`);
  check(res, {
    'event detail status is 200': (r) => r.status === 200,
    'event has id': (r) => {
      const body = JSON.parse(r.body);
      return body.id === 1;
    },
  }) || errorRate.add(1);

  sleep(1);

  // Test 3: Add to basket
  const basketPayload = JSON.stringify({
    event_id: 1,
    quantity: 2,
  });
  
  const basketParams = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  res = http.post(`${BASE_URL}/api/basket`, basketPayload, basketParams);
  check(res, {
    'add to basket status is 201': (r) => r.status === 201,
  }) || errorRate.add(1);

  sleep(1);

  // Test 4: Checkout
  const checkoutPayload = JSON.stringify({
    items: [
      { event_id: 1, price: 99.99, quantity: 2 },
    ],
  });

  res = http.post(`${BASE_URL}/api/checkout`, checkoutPayload, basketParams);
  check(res, {
    'checkout status is 200': (r) => r.status === 200,
    'checkout has transaction_id': (r) => {
      const body = JSON.parse(r.body);
      return body.transaction_id !== undefined;
    },
  }) || errorRate.add(1);

  sleep(2);
}
