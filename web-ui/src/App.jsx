import React from 'react'
import { Routes, Route } from 'react-router-dom'
import Layout from './components/Layout'
import Dashboard from './pages/Dashboard'
import PipelineDemo from './pages/PipelineDemo'
import DataUpload from './pages/DataUpload'
import Monitoring from './pages/Monitoring'
import Settings from './pages/Settings'

function App() {
  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50">
      <Layout>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/demo" element={<PipelineDemo />} />
          <Route path="/upload" element={<DataUpload />} />
          <Route path="/monitoring" element={<Monitoring />} />
          <Route path="/settings" element={<Settings />} />
        </Routes>
      </Layout>
    </div>
  )
}

export default App
