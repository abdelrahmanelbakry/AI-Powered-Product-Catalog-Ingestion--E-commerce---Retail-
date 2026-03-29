import React, { useState, useEffect } from 'react'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, AreaChart, Area } from 'recharts'

const Monitoring = () => {
  const [timeRange, setTimeRange] = useState('24h')
  const [metrics, setMetrics] = useState({
    lambdaInvocations: [],
    lambdaErrors: [],
    lambdaDuration: [],
    stepFunctionExecutions: [],
    bedrockCalls: []
  })

  const [alerts, setAlerts] = useState([
    {
      id: 1,
      type: 'warning',
      message: 'Lambda function duration approaching threshold',
      timestamp: '2024-01-15T10:30:00Z',
      service: 'Ingestion Lambda'
    },
    {
      id: 2,
      type: 'info',
      message: 'Step Functions execution completed successfully',
      timestamp: '2024-01-15T10:25:00Z',
      service: 'Main Pipeline'
    },
    {
      id: 3,
      type: 'error',
      message: 'Bedrock API rate limit exceeded',
      timestamp: '2024-01-15T10:20:00Z',
      service: 'Processing Lambda'
    }
  ])

  const [systemHealth, setSystemHealth] = useState({
    ingestion: 'healthy',
    processing: 'healthy',
    database: 'healthy',
    storage: 'healthy'
  })

  useEffect(() => {
    // Generate mock time series data
    const generateTimeSeriesData = (baseValue, variance, points) => {
      const data = []
      const now = new Date()
      for (let i = points - 1; i >= 0; i--) {
        const timestamp = new Date(now - i * 3600000) // 1 hour intervals
        data.push({
          time: timestamp.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }),
          value: baseValue + (Math.random() - 0.5) * variance
        })
      }
      return data
    }

    setMetrics({
      lambdaInvocations: generateTimeSeriesData(50, 20, 24),
      lambdaErrors: generateTimeSeriesData(2, 3, 24),
      lambdaDuration: generateTimeSeriesData(150, 50, 24),
      stepFunctionExecutions: generateTimeSeriesData(10, 5, 24),
      bedrockCalls: generateTimeSeriesData(30, 15, 24)
    })
  }, [timeRange])

  const getHealthColor = (status) => {
    switch (status) {
      case 'healthy': return 'bg-green-500'
      case 'warning': return 'bg-yellow-500'
      case 'error': return 'bg-red-500'
      default: return 'bg-gray-500'
    }
  }

  const getAlertIcon = (type) => {
    switch (type) {
      case 'error': return '🔴'
      case 'warning': return '🟡'
      case 'info': return '🔵'
      default: return '⚪'
    }
  }

  const formatTimestamp = (timestamp) => {
    return new Date(timestamp).toLocaleString()
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Monitoring</h1>
        <p className="mt-1 text-sm text-gray-600">
          Real-time monitoring of the product catalog pipeline
        </p>
      </div>

      {/* System Health */}
      <div className="bg-white shadow rounded-lg p-6">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-lg font-medium text-gray-900">System Health</h3>
          <select
            value={timeRange}
            onChange={(e) => setTimeRange(e.target.value)}
            className="block w-32 pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-blue-500 focus:border-blue-500 sm:text-sm rounded-md"
          >
            <option value="1h">Last Hour</option>
            <option value="24h">Last 24 Hours</option>
            <option value="7d">Last 7 Days</option>
            <option value="30d">Last 30 Days</option>
          </select>
        </div>
        
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
          {Object.entries(systemHealth).map(([service, status]) => (
            <div key={service} className="flex items-center space-x-3 p-4 border border-gray-200 rounded-lg">
              <div className={`w-3 h-3 rounded-full ${getHealthColor(status)}`}></div>
              <div>
                <div className="text-sm font-medium text-gray-900 capitalize">{service}</div>
                <div className="text-xs text-gray-500 capitalize">{status}</div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Metrics Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Lambda Invocations */}
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Lambda Invocations</h3>
          <ResponsiveContainer width="100%" height={300}>
            <AreaChart data={metrics.lambdaInvocations}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis />
              <Tooltip />
              <Area type="monotone" dataKey="value" stroke="#3b82f6" fill="#3b82f6" fillOpacity={0.3} />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Lambda Duration */}
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Lambda Duration (ms)</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={metrics.lambdaDuration}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis />
              <Tooltip />
              <Line type="monotone" dataKey="value" stroke="#10b981" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Step Functions Executions */}
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Step Functions Executions</h3>
          <ResponsiveContainer width="100%" height={300}>
            <AreaChart data={metrics.stepFunctionExecutions}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis />
              <Tooltip />
              <Area type="monotone" dataKey="value" stroke="#8b5cf6" fill="#8b5cf6" fillOpacity={0.3} />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Bedrock API Calls */}
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Bedrock API Calls</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={metrics.bedrockCalls}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis />
              <Tooltip />
              <Line type="monotone" dataKey="value" stroke="#f59e0b" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Alerts */}
      <div className="bg-white shadow rounded-lg">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-medium text-gray-900">Recent Alerts</h3>
        </div>
        <div className="divide-y divide-gray-200">
          {alerts.map((alert) => (
            <div key={alert.id} className="px-6 py-4">
              <div className="flex items-start space-x-3">
                <div className="flex-shrink-0 text-2xl">
                  {getAlertIcon(alert.type)}
                </div>
                <div className="flex-1">
                  <div className="flex items-center justify-between">
                    <p className="text-sm text-gray-900">{alert.message}</p>
                    <p className="text-xs text-gray-500">{formatTimestamp(alert.timestamp)}</p>
                  </div>
                  <p className="text-xs text-gray-500 mt-1">Service: {alert.service}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Performance Metrics */}
      <div className="bg-white shadow rounded-lg p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-6">Performance Metrics</h3>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <div className="text-center">
            <div className="text-3xl font-bold text-blue-600">99.9%</div>
            <div className="text-sm text-gray-500 mt-1">Uptime</div>
          </div>
          <div className="text-center">
            <div className="text-3xl font-bold text-green-600">1.2s</div>
            <div className="text-sm text-gray-500 mt-1">Avg Response Time</div>
          </div>
          <div className="text-center">
            <div className="text-3xl font-bold text-purple-600">15,234</div>
            <div className="text-sm text-gray-500 mt-1">Records Processed</div>
          </div>
          <div className="text-center">
            <div className="text-3xl font-bold text-yellow-600">94.2%</div>
            <div className="text-sm text-gray-500 mt-1">AI Confidence</div>
          </div>
        </div>
      </div>

      {/* Resource Utilization */}
      <div className="bg-white shadow rounded-lg p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-6">Resource Utilization</h3>
        <div className="space-y-4">
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-gray-900">Lambda Functions</span>
              <span className="text-sm text-gray-500">45% utilized</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div className="bg-blue-600 h-2 rounded-full" style={{ width: '45%' }}></div>
            </div>
          </div>
          
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-gray-900">RDS Database</span>
              <span className="text-sm text-gray-500">62% utilized</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div className="bg-green-600 h-2 rounded-full" style={{ width: '62%' }}></div>
            </div>
          </div>
          
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-gray-900">S3 Storage</span>
              <span className="text-sm text-gray-500">28% utilized</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div className="bg-purple-600 h-2 rounded-full" style={{ width: '28%' }}></div>
            </div>
          </div>
          
          <div>
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-gray-900">Bedrock API</span>
              <span className="text-sm text-gray-500">78% utilized</span>
            </div>
            <div className="w-full bg-gray-200 rounded-full h-2">
              <div className="bg-yellow-600 h-2 rounded-full" style={{ width: '78%' }}></div>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default Monitoring
