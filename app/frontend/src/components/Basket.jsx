import { useState } from 'react'
import axios from 'axios'
import './Basket.css'

function Basket({ basket, removeFromBasket, updateQuantity }) {
  const [loading, setLoading] = useState(false)
  const [checkoutSuccess, setCheckoutSuccess] = useState(false)
  const [error, setError] = useState(null)

  const total = basket.reduce((sum, item) => sum + (item.price * item.quantity), 0)

  const handleCheckout = async () => {
    setLoading(true)
    setError(null)
    
    try {
      const response = await axios.post('/api/checkout', {
        items: basket.map(item => ({
          event_id: item.id,
          price: item.price,
          quantity: item.quantity
        }))
      })
      
      setCheckoutSuccess(true)
      setLoading(false)
      
      // Clear basket after 2 seconds
      setTimeout(() => {
        basket.forEach(item => removeFromBasket(item.id))
        setCheckoutSuccess(false)
      }, 2000)
    } catch (err) {
      setError('Checkout failed. Please try again.')
      setLoading(false)
    }
  }

  if (basket.length === 0 && !checkoutSuccess) {
    return (
      <div className="basket-empty">
        <h2>Your Basket</h2>
        <p>Your basket is empty. Browse events to get started!</p>
      </div>
    )
  }

  if (checkoutSuccess) {
    return (
      <div className="checkout-success card">
        <h2>✅ Checkout Successful!</h2>
        <p>Your tickets have been confirmed (mock transaction).</p>
      </div>
    )
  }

  return (
    <div className="basket">
      <h2>Your Basket</h2>
      
      {error && <div className="error">{error}</div>}
      
      <div className="basket-items">
        {basket.map(item => (
          <div key={item.id} className="basket-item card">
            <div className="basket-item-info">
              <h3>{item.name}</h3>
              <p className="basket-item-venue">📍 {item.venue}</p>
              <p className="basket-item-date">📅 {item.date}</p>
              <p className="basket-item-price">£{item.price.toFixed(2)} each</p>
            </div>
            
            <div className="basket-item-controls">
              <div className="quantity-control">
                <label>Quantity:</label>
                <input
                  type="number"
                  min="1"
                  max="10"
                  value={item.quantity}
                  onChange={(e) => updateQuantity(item.id, parseInt(e.target.value) || 1)}
                />
              </div>
              
              <p className="basket-item-subtotal">
                Subtotal: £{(item.price * item.quantity).toFixed(2)}
              </p>
              
              <button
                className="btn btn-danger"
                onClick={() => removeFromBasket(item.id)}
              >
                Remove
              </button>
            </div>
          </div>
        ))}
      </div>

      <div className="basket-summary card">
        <div className="basket-total">
          <h3>Total</h3>
          <p className="total-amount">£{total.toFixed(2)}</p>
        </div>
        
        <button
          className="btn btn-primary btn-large"
          onClick={handleCheckout}
          disabled={loading}
        >
          {loading ? 'Processing...' : 'Checkout (Mock)'}
        </button>
      </div>
    </div>
  )
}

export default Basket
