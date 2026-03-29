import React, { useState, useEffect } from 'react'
import { Link } from 'react-router-dom'
import { 
  CloudArrowUpIcon, 
  PlayIcon, 
  ChartBarIcon,
  CpuChipIcon,
  DocumentTextIcon,
  CheckCircleIcon
} from '@heroicons/react/24/outline'
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, BarChart, Bar } from 'recharts'

const Dashboard = () => {
  const [stats, setStats] = useState({
    totalRecords: 0,
    processedRecords: 0,
    errorRate: 0,
    avgProcessingTime: 0
  })

  const [processingData, setProcessingData] = useState([
    { time: '00:00', records: 45 },
    { time: '04:00', records: 52 },
    { time: '08:00', records: 38 },
    { time: '12:00', records: 65 },
    { time: '16:00', records: 48 },
    { time: '20:00', records: 58 }
  ])

  const [qualityData, setQualityData] = useState([
    { category: 'Brand', confidence: 92 },
    { category: 'Category', confidence: 88 },
    { category: 'Color', confidence: 95 },
    { category: 'Size', confidence: 78 },
    { category: 'Price', confidence: 85 }
  ])

  useEffect(() => {
    // Simulate real-time data updates
    const interval = setInterval(() => {
      setStats(prev => ({
        totalRecords: prev.totalRecords + Math.floor(Math.random() * 10),
        processedRecords: prev.processedRecords + Math.floor(Math.random() * 8),
        errorRate: Math.max(0, Math.min(100, prev.errorRate + (Math.random() - 0.5) * 5)),
        avgProcessingTime: Math.max(1000, prev.avgProcessingTime + (Math.random() - 0.5) * 200)
      }))
    }, 3000)

    return () => clearInterval(interval)
  }, [])

  const statCards = [
    {
      title: 'Total Records',
      value: stats.totalRecords.toLocaleString(),
      change: '+12.5%',
      changeType: 'positive',
      icon: DocumentTextIcon,
      color: 'blue'
    },
    {
      title: 'Processed Records',
      value: stats.processedRecords.toLocaleString(),
      change: '+8.2%',
      changeType: 'positive',
      icon: CheckCircleIcon,
      color: 'green'
    },
    {
      title: 'Error Rate',
      value: `${stats.errorRate.toFixed(1)}%`,
      change: '-2.1%',
      changeType: 'positive',
      icon: ChartBarIcon,
      color: 'yellow'
    },
    {
      title: 'Avg Processing Time',
      value: `${(stats.avgProcessingTime / 1000).toFixed(1)}s`,
      change: '-0.5s',
      changeType: 'positive',
      icon: CpuChipIcon,
      color: 'purple'
    }
  ]

  const quickActions = [
    {
      title: 'Upload Product Data',
      description: 'Upload CSV or Excel files for processing',
      icon: CloudArrowUpIcon,
      href: '/upload',
      color: 'blue'
    },
    {
      title: 'Run Pipeline Demo',
      description: 'See the AI pipeline in action with sample data',
      icon: PlayIcon,
      href: '/demo',
      color: 'green'
    },
    {
      title: 'View Monitoring',
      description: 'Monitor system performance and metrics',
      icon: ChartBarIcon,
      href: '/monitoring',
      color: 'purple'
    }
  ]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Dashboard</h1>
        <p className="mt-1 text-sm text-gray-600">
          Monitor your AI-powered product catalog pipeline performance
        </p>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        {statCards.map((stat) => (
          <div key={stat.title} className="bg-white overflow-hidden shadow rounded-lg">
            <div className="p-5">
              <div className="flex items-center">
                <div className={`flex-shrink-0 bg-${stat.color}-100 rounded-md p-3`}>
                  <stat.icon className={`h-6 w-6 text-${stat.color}-600`} aria-hidden="true" />
                </div>
                <div className="ml-5 w-0 flex-1">
                  <dl>
                    <dt className="text-sm font-medium text-gray-500 truncate">{stat.title}</dt>
                    <dd className="flex items-baseline">
                      <div className="text-2xl font-semibold text-gray-900">{stat.value}</div>
                      <div className={`ml-2 flex items-baseline text-sm font-semibold ${
                        stat.changeType === 'positive' ? 'text-green-600' : 'text-red-600'
                      }`}>
                        {stat.change}
                      </div>
                    </dd>
                  </dl>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Charts */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Processing Volume Chart */}
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Processing Volume</h3>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={processingData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="time" />
              <YAxis />
              <Tooltip />
              <Line type="monotone" dataKey="records" stroke="#3b82f6" strokeWidth={2} />
            </LineChart>
          </ResponsiveContainer>
        </div>

        {/* Data Quality Chart */}
        <div className="bg-white p-6 rounded-lg shadow">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Data Quality Scores</h3>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={qualityData}>
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis dataKey="category" />
              <YAxis />
              <Tooltip />
              <Bar dataKey="confidence" fill="#10b981" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Quick Actions */}
      <div className="bg-white shadow rounded-lg">
        <div className="px-4 py-5 sm:p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Quick Actions</h3>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-3">
            {quickActions.map((action) => (
              <Link
                key={action.title}
                to={action.href}
                className={`relative block p-6 border-2 border-gray-300 rounded-lg hover:border-${action.color}-500 transition-colors`}
              >
                <div className="flex items-center">
                  <div className={`flex-shrink-0 bg-${action.color}-100 rounded-md p-3`}>
                    <action.icon className={`h-6 w-6 text-${action.color}-600`} aria-hidden="true" />
                  </div>
                  <div className="ml-4">
                    <h3 className="text-base font-medium text-gray-900">{action.title}</h3>
                    <p className="mt-1 text-sm text-gray-500">{action.description}</p>
                  </div>
                </div>
              </Link>
            ))}
          </div>
        </div>
      </div>

      {/* Recent Activity */}
      <div className="bg-white shadow rounded-lg">
        <div className="px-4 py-5 sm:p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4">Recent Activity</h3>
          <div className="flow-root">
            <ul className="-mb-8">
              <li className="relative pb-8">
                <div className="relative flex space-x-3">
                  <div className="flex-shrink-0">
                    <div className="h-8 w-8 rounded-full bg-green-100 flex items-center justify-center">
                      <CheckCircleIcon className="h-5 w-5 text-green-600" />
                    </div>
                  </div>
                  <div className="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
                    <div>
                      <p className="text-sm text-gray-900">Successfully processed 150 product records</p>
                    </div>
                    <div className="text-right text-sm whitespace-nowrap text-gray-500">
                      2 minutes ago
                    </div>
                  </div>
                </div>
              </li>
              <li className="relative pb-8">
                <div className="relative flex space-x-3">
                  <div className="flex-shrink-0">
                    <div className="h-8 w-8 rounded-full bg-blue-100 flex items-center justify-center">
                      <CloudArrowUpIcon className="h-5 w-5 text-blue-600" />
                    </div>
                  </div>
                  <div className="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
                    <div>
                      <p className="text-sm text-gray-900">New file uploaded: products_batch_001.csv</p>
                    </div>
                    <div className="text-right text-sm whitespace-nowrap text-gray-500">
                      5 minutes ago
                    </div>
                  </div>
                </div>
              </li>
              <li className="relative">
                <div className="relative flex space-x-3">
                  <div className="flex-shrink-0">
                    <div className="h-8 w-8 rounded-full bg-yellow-100 flex items-center justify-center">
                      <ChartBarIcon className="h-5 w-5 text-yellow-600" />
                    </div>
                  </div>
                  <div className="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
                    <div>
                      <p className="text-sm text-gray-900">AI model confidence score improved to 94.2%</p>
                    </div>
                    <div className="text-right text-sm whitespace-nowrap text-gray-500">
                      15 minutes ago
                    </div>
                  </div>
                </div>
              </li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}

export default Dashboard
