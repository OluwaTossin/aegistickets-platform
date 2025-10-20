import { useState, useEffect } from 'react'
import { BrowserRouter as Router, Routes, Route, Link } from 'react-router-dom'
import EventList from './components/EventList'
import EventDetail from './components/EventDetail'
import Basket from './components/Basket'
import './App.css'

function App() {
  const [basket, setBasket] = useState([])

  const addToBasket = (event, quantity = 1) => {
    setBasket(prevBasket => {
      const existingItem = prevBasket.find(item => item.id === event.id)
      if (existingItem) {
        return prevBasket.map(item =>
          item.id === event.id
            ? { ...item, quantity: item.quantity + quantity }
            : item
        )
      }
      return [...prevBasket, { ...event, quantity }]
    })
  }

  const removeFromBasket = (eventId) => {
    setBasket(prevBasket => prevBasket.filter(item => item.id !== eventId))
  }

  const updateQuantity = (eventId, quantity) => {
    setBasket(prevBasket =>
      prevBasket.map(item =>
        item.id === eventId ? { ...item, quantity } : item
      )
    )
  }

  return (
    <Router>
      <div className="app">
        <header className="app-header">
          <div className="container">
            <h1>
              <Link to="/">🎫 AegisTickets</Link>
            </h1>
            <nav>
              <Link to="/">Events</Link>
              <Link to="/basket">
                Basket ({basket.reduce((sum, item) => sum + item.quantity, 0)})
              </Link>
            </nav>
          </div>
        </header>

        <main className="container">
          <Routes>
            <Route path="/" element={<EventList addToBasket={addToBasket} />} />
            <Route path="/events/:id" element={<EventDetail addToBasket={addToBasket} />} />
            <Route
              path="/basket"
              element={
                <Basket
                  basket={basket}
                  removeFromBasket={removeFromBasket}
                  updateQuantity={updateQuantity}
                />
              }
            />
          </Routes>
        </main>

        <footer className="app-footer">
          <div className="container">
            <p>&copy; 2025 AegisTickets. Built with reliability in mind.</p>
            <p className="slo-badge">
              SLO: 99.9% availability | p95 latency &lt; 800ms
            </p>
          </div>
        </footer>
      </div>
    </Router>
  )
}

export default App
