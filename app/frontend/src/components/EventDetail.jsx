import { useState, useEffect } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import axios from 'axios'
import './EventDetail.css'

function EventDetail({ addToBasket }) {
  const { id } = useParams()
  const navigate = useNavigate()
  const [event, setEvent] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [quantity, setQuantity] = useState(1)

  useEffect(() => {
    fetchEvent()
  }, [id])

  const fetchEvent = async () => {
    try {
      const response = await axios.get(`/api/events/${id}`)
      setEvent(response.data)
      setLoading(false)
    } catch (err) {
      setError('Failed to load event details.')
      setLoading(false)
    }
  }

  const handleAddToBasket = () => {
    addToBasket(event, quantity)
    navigate('/basket')
  }

  if (loading) {
    return <div className="loading">Loading event details...</div>
  }

  if (error) {
    return <div className="error">{error}</div>
  }

  return (
    <div className="event-detail">
      <button className="btn btn-secondary" onClick={() => navigate(-1)}>
        ← Back
      </button>
      
      <div className="card event-detail-content">
        <h2>{event.name}</h2>
        <div className="event-info">
          <p className="event-date">📅 {event.date}</p>
          <p className="event-venue">📍 {event.venue}</p>
          <p className="event-tickets">
            🎫 {event.available_tickets} tickets available
          </p>
        </div>
        
        <div className="event-description">
          <h3>About this event</h3>
          <p>{event.description}</p>
        </div>

        <div className="event-purchase">
          <p className="event-price">£{event.price.toFixed(2)} per ticket</p>
          
          <div className="quantity-selector">
            <label htmlFor="quantity">Quantity:</label>
            <input
              type="number"
              id="quantity"
              min="1"
              max={Math.min(10, event.available_tickets)}
              value={quantity}
              onChange={(e) => setQuantity(parseInt(e.target.value) || 1)}
            />
          </div>

          <div className="purchase-total">
            <strong>Total: £{(event.price * quantity).toFixed(2)}</strong>
          </div>

          <button
            className="btn btn-primary btn-large"
            onClick={handleAddToBasket}
            disabled={event.available_tickets === 0}
          >
            {event.available_tickets === 0 ? 'Sold Out' : 'Add to Basket'}
          </button>
        </div>
      </div>
    </div>
  )
}

export default EventDetail
