"""
Unit tests for AegisTickets Backend
"""
import pytest
from app import app


@pytest.fixture
def client():
    """Create test client"""
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client


def test_health_endpoint(client):
    """Test health check endpoint"""
    response = client.get('/healthz')
    assert response.status_code == 200
    assert response.json['status'] == 'healthy'


def test_metrics_endpoint(client):
    """Test Prometheus metrics endpoint"""
    response = client.get('/metrics')
    assert response.status_code == 200
    assert b'http_requests_total' in response.data


def test_get_events(client):
    """Test get events endpoint"""
    response = client.get('/api/events')
    assert response.status_code == 200
    assert 'events' in response.json
    assert response.json['count'] >= 0


def test_get_single_event(client):
    """Test get single event endpoint"""
    response = client.get('/api/events/1')
    assert response.status_code == 200
    assert response.json['id'] == 1


def test_add_to_basket(client):
    """Test add to basket endpoint"""
    response = client.post('/api/basket', json={'event_id': 1, 'quantity': 2})
    assert response.status_code == 201
    assert response.json['event_id'] == 1


def test_checkout(client):
    """Test checkout endpoint"""
    items = [{'price': 99.99, 'quantity': 2}]
    response = client.post('/api/checkout', json={'items': items})
    assert response.status_code == 200
    assert 'transaction_id' in response.json


def test_404_handler(client):
    """Test 404 error handler"""
    response = client.get('/nonexistent')
    assert response.status_code == 404
    assert 'error' in response.json
