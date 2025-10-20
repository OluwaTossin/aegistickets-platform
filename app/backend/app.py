"""
AegisTickets Backend - Flask API with Prometheus instrumentation
"""
import os
import time
import psycopg2
from flask import Flask, jsonify, request
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from functools import wraps

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'code']
)

REQUEST_LATENCY = Histogram(
    'http_request_latency_seconds',
    'HTTP request latency in seconds',
    ['method', 'endpoint']
)

DB_CONNECTIONS = Gauge(
    'db_active_connections',
    'Number of active database connections'
)

ERROR_COUNT = Counter(
    'http_errors_total',
    'Total HTTP errors',
    ['method', 'endpoint', 'code']
)


def get_db_connection():
    """Get PostgreSQL database connection"""
    database_url = os.getenv('DATABASE_URL')
    if not database_url:
        return None
    try:
        conn = psycopg2.connect(database_url)
        return conn
    except Exception as e:
        app.logger.error(f"Database connection failed: {e}")
        return None


def prometheus_metrics(f):
    """Decorator to track request metrics"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        start_time = time.time()
        endpoint = request.endpoint or 'unknown'
        method = request.method
        
        try:
            response = f(*args, **kwargs)
            status_code = response[1] if isinstance(response, tuple) else 200
            
            # Record metrics
            REQUEST_COUNT.labels(method=method, endpoint=endpoint, code=status_code).inc()
            REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(time.time() - start_time)
            
            if status_code >= 500:
                ERROR_COUNT.labels(method=method, endpoint=endpoint, code=status_code).inc()
            
            return response
        except Exception as e:
            REQUEST_COUNT.labels(method=method, endpoint=endpoint, code=500).inc()
            ERROR_COUNT.labels(method=method, endpoint=endpoint, code=500).inc()
            REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(time.time() - start_time)
            raise e
    
    return decorated_function


@app.route('/healthz')
def health():
    """Liveness probe - basic health check"""
    return jsonify({"status": "healthy"}), 200


@app.route('/readiness')
def readiness():
    """Readiness probe - check database connectivity"""
    conn = get_db_connection()
    if conn:
        try:
            cursor = conn.cursor()
            cursor.execute('SELECT 1')
            cursor.close()
            conn.close()
            return jsonify({"status": "ready", "database": "connected"}), 200
        except Exception as e:
            return jsonify({"status": "not ready", "database": str(e)}), 503
    else:
        return jsonify({"status": "not ready", "database": "no connection"}), 503


@app.route('/metrics')
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}


@app.route('/api/events', methods=['GET'])
@prometheus_metrics
def get_events():
    """Get list of events (mock data for now)"""
    events = [
        {
            "id": 1,
            "name": "Tech Conference 2025",
            "date": "2025-11-15",
            "venue": "London Convention Center",
            "available_tickets": 500,
            "price": 99.99
        },
        {
            "id": 2,
            "name": "Summer Music Festival",
            "date": "2025-07-20",
            "venue": "Hyde Park",
            "available_tickets": 2000,
            "price": 149.99
        },
        {
            "id": 3,
            "name": "Comedy Night",
            "date": "2025-06-10",
            "venue": "O2 Arena",
            "available_tickets": 150,
            "price": 45.00
        }
    ]
    return jsonify({"events": events, "count": len(events)}), 200


@app.route('/api/events/<int:event_id>', methods=['GET'])
@prometheus_metrics
def get_event(event_id):
    """Get single event details"""
    # Mock event detail
    event = {
        "id": event_id,
        "name": f"Event {event_id}",
        "date": "2025-11-15",
        "venue": "London Convention Center",
        "available_tickets": 500,
        "price": 99.99,
        "description": "An amazing event you won't want to miss!"
    }
    return jsonify(event), 200


@app.route('/api/basket', methods=['POST'])
@prometheus_metrics
def add_to_basket():
    """Add event to basket (mock)"""
    data = request.get_json()
    event_id = data.get('event_id')
    quantity = data.get('quantity', 1)
    
    if not event_id:
        return jsonify({"error": "event_id required"}), 400
    
    return jsonify({
        "message": "Added to basket",
        "event_id": event_id,
        "quantity": quantity
    }), 201


@app.route('/api/checkout', methods=['POST'])
@prometheus_metrics
def checkout():
    """Mock checkout endpoint"""
    data = request.get_json()
    basket_items = data.get('items', [])
    
    total = sum(item.get('price', 0) * item.get('quantity', 1) for item in basket_items)
    
    return jsonify({
        "message": "Checkout successful (mock)",
        "total": total,
        "transaction_id": "TXN-" + str(int(time.time()))
    }), 200


@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    REQUEST_COUNT.labels(method=request.method, endpoint='404', code=404).inc()
    return jsonify({"error": "Not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    REQUEST_COUNT.labels(method=request.method, endpoint='500', code=500).inc()
    ERROR_COUNT.labels(method=request.method, endpoint='500', code=500).inc()
    return jsonify({"error": "Internal server error"}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
