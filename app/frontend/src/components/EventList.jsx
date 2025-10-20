import { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import axios from 'axios'
import './EventList.css'

function EventList({ addToBasket }) {
  const [events, setEvents] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)

  useEffect(() => {
    fetchEvents()
  }, [])

  const fetchEvents = async () => {
    try {
      const response = await axios.get('/api/events')
      setEvents(response.data.events || [])
      setLoading(false)
    } catch (err) {
      setError('Failed to load events. Please try again later.')
      setLoading(false)
    }
  }

  const handleAddToBasket = (event) => {
    addToBasket(event, 1)
  }

  if (loading) {
    return <div className="loading">Loading events...</div>
  }

  if (error) {
    return <div className="error">{error}</div>
  }

  return (
    <div className="event-list">
      <h2>Upcoming Events</h2>
      <div className="events-grid">
        {events.map(event => (
          <div key={event.id} className="event-card card">
            <h3>{event.name}</h3>
            <div className="event-details">
              <p className="event-date">📅 {event.date}</p>
              <p className="event-venue">📍 {event.venue}</p>
              <p className="event-tickets">
                🎫 {event.available_tickets} tickets available
              </p>
              <p className="event-price">💷 £{event.price.toFixed(2)}</p>
            </div>
            <div className="event-actions">
              <Link to={`/events/${event.id}`} className="btn btn-secondary">
                View Details
              </Link>
              <button
                className="btn btn-primary"
                onClick={() => handleAddToBasket(event)}
              >
                Add to Basket
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}

export default EventList
