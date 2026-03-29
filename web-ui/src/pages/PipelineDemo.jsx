import React, { useState } from 'react'
import toast from 'react-hot-toast'
import { 
  PlayIcon, 
  StopIcon, 
  ArrowPathIcon,
  CheckCircleIcon,
  ExclamationTriangleIcon,
  ClockIcon
} from '@heroicons/react/24/outline'

const PipelineDemo = () => {
  const [isRunning, setIsRunning] = useState(false)
  const [currentStep, setCurrentStep] = useState(0)
  const [stepStatus, setStepStatus] = useState({})
  const [results, setResults] = useState(null)

  const pipelineSteps = [
    {
      id: 'upload',
      name: 'File Upload',
      description: 'Upload product catalog to S3',
      icon: '📁',
      duration: 2000
    },
    {
      id: 'ingestion',
      name: 'Data Ingestion',
      description: 'Parse and store raw data in RDS',
      icon: '🔄',
      duration: 3000
    },
    {
      id: 'ai-processing',
      name: 'AI Enrichment',
      description: 'Process data with AWS Bedrock',
      icon: '🤖',
      duration: 4000
    },
    {
      id: 'storage',
      name: 'Store Results',
      description: 'Save enriched data to S3',
      icon: '💾',
      duration: 2000
    },
    {
      id: 'completion',
      name: 'Pipeline Complete',
      description: 'All processing finished successfully',
      icon: '✅',
      duration: 1000
    }
  ]

  const sampleData = [
    {
      original: {
        product_name: "nike air max 270 running shoes - black/white size 10",
        price: "$129.99",
        description: "comfortable running shoes with air cushioning"
      },
      enriched: {
        name_clean: "Nike Air Max 270 Running Shoes",
        brand: "Nike",
        category: "Footwear",
        color: "Black/White",
        size: "10",
        price: "$129.99",
        description_clean: "Comfortable running shoes with air cushioning technology",
        duplicate_flag: false,
        confidence_score: 0.85,
        extracted_attributes: {
          material: null,
          style: "Running",
          gender: "Unisex",
          season: null
        }
      }
    },
    {
      original: {
        product_name: "adidas ultraboost 22",
        price: "$159.99",
        description: "high-performance running shoes"
      },
      enriched: {
        name_clean: "Adidas Ultraboost 22 Running Shoes",
        brand: "Adidas",
        category: "Footwear",
        color: null,
        size: null,
        price: "$159.99",
        description_clean: "High-performance running shoes with advanced technology",
        duplicate_flag: false,
        confidence_score: 0.92,
        extracted_attributes: {
          material: null,
          style: "Running",
          gender: "Unisex",
          season: null
        }
      }
    },
    {
      original: {
        product_name: "apple iphone 14 pro",
        price: "$999.99",
        description: "latest smartphone with advanced features"
      },
      enriched: {
        name_clean: "Apple iPhone 14 Pro",
        brand: "Apple",
        category: "Electronics",
        color: null,
        size: null,
        price: "$999.99",
        description_clean: "Latest smartphone with advanced camera and processing features",
        duplicate_flag: false,
        confidence_score: 0.95,
        extracted_attributes: {
          material: null,
          style: null,
          gender: null,
          season: null
        }
      }
    }
  ]

  const runPipeline = async () => {
    setIsRunning(true)
    setCurrentStep(0)
    setStepStatus({})
    setResults(null)

    for (let i = 0; i < pipelineSteps.length; i++) {
      const step = pipelineSteps[i]
      setCurrentStep(i)
      
      // Set step to running
      setStepStatus(prev => ({
        ...prev,
        [step.id]: 'running'
      }))

      // Simulate step execution
      await new Promise(resolve => setTimeout(resolve, step.duration))

      // Set step to completed
      setStepStatus(prev => ({
        ...prev,
        [step.id]: 'completed'
      }))

      // Show toast notification
      if (i < pipelineSteps.length - 1) {
        toast.success(`${step.name} completed successfully!`)
      }
    }

    // Set final results
    setResults({
      totalRecords: sampleData.length,
      processedRecords: sampleData.length,
      errorCount: 0,
      avgConfidence: 0.91,
      processingTime: 12.5
    })

    setIsRunning(false)
    toast.success('Pipeline completed successfully! 🎉')
  }

  const stopPipeline = () => {
    setIsRunning(false)
    toast('Pipeline stopped', {
      icon: '⏹️',
    })
  }

  const resetPipeline = () => {
    setIsRunning(false)
    setCurrentStep(0)
    setStepStatus({})
    setResults(null)
    toast('Pipeline reset')
  }

  const getStepIcon = (status) => {
    switch (status) {
      case 'running':
        return <ArrowPathIcon className="h-5 w-5 text-blue-600 animate-spin" />
      case 'completed':
        return <CheckCircleIcon className="h-5 w-5 text-green-600" />
      case 'error':
        return <ExclamationTriangleIcon className="h-5 w-5 text-red-600" />
      default:
        return <ClockIcon className="h-5 w-5 text-gray-400" />
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Pipeline Demo</h1>
        <p className="mt-1 text-sm text-gray-600">
          Watch the AI-powered product catalog pipeline in action with sample data
        </p>
      </div>

      {/* Controls */}
      <div className="bg-white shadow rounded-lg p-6">
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-lg font-medium text-gray-900">Pipeline Controls</h3>
            <p className="text-sm text-gray-500 mt-1">
              {isRunning ? 'Pipeline is running...' : 'Ready to start pipeline'}
            </p>
          </div>
          <div className="flex space-x-3">
            {!isRunning ? (
              <button
                onClick={runPipeline}
                className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <PlayIcon className="h-4 w-4 mr-2" />
                Start Pipeline
              </button>
            ) : (
              <button
                onClick={stopPipeline}
                className="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
              >
                <StopIcon className="h-4 w-4 mr-2" />
                Stop Pipeline
              </button>
            )}
            <button
              onClick={resetPipeline}
              disabled={isRunning}
              className="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
            >
              <ArrowPathIcon className="h-4 w-4 mr-2" />
              Reset
            </button>
          </div>
        </div>
      </div>

      {/* Pipeline Steps */}
      <div className="bg-white shadow rounded-lg p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-6">Pipeline Steps</h3>
        <div className="space-y-4">
          {pipelineSteps.map((step, index) => (
            <div
              key={step.id}
              className={`flex items-center space-x-4 p-4 rounded-lg border-2 transition-all ${
                index === currentStep && isRunning
                  ? 'border-blue-500 bg-blue-50'
                  : stepStatus[step.id] === 'completed'
                  ? 'border-green-500 bg-green-50'
                  : 'border-gray-200'
              }`}
            >
              <div className="flex-shrink-0">
                <div className={`w-12 h-12 rounded-full flex items-center justify-center text-lg ${
                  index === currentStep && isRunning
                    ? 'bg-blue-100'
                    : stepStatus[step.id] === 'completed'
                    ? 'bg-green-100'
                    : 'bg-gray-100'
                }`}>
                  {stepStatus[step.id] ? getStepIcon(stepStatus[step.id]) : step.icon}
                </div>
              </div>
              <div className="flex-1">
                <h4 className="text-base font-medium text-gray-900">{step.name}</h4>
                <p className="text-sm text-gray-500">{step.description}</p>
              </div>
              <div className="flex-shrink-0">
                {index === currentStep && isRunning && (
                  <div className="flex items-center text-blue-600">
                    <ArrowPathIcon className="h-4 w-4 mr-1 animate-spin" />
                    <span className="text-sm">Processing...</span>
                  </div>
                )}
                {stepStatus[step.id] === 'completed' && (
                  <div className="flex items-center text-green-600">
                    <CheckCircleIcon className="h-4 w-4 mr-1" />
                    <span className="text-sm">Completed</span>
                  </div>
                )}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Sample Data */}
      <div className="bg-white shadow rounded-lg p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-6">Sample Data Transformation</h3>
        <div className="space-y-6">
          {sampleData.map((item, index) => (
            <div key={index} className="border border-gray-200 rounded-lg p-4">
              <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                {/* Original Data */}
                <div>
                  <h4 className="text-sm font-medium text-gray-900 mb-3">Original Data</h4>
                  <div className="bg-gray-50 rounded p-3">
                    <pre className="text-xs text-gray-700 whitespace-pre-wrap">
                      {JSON.stringify(item.original, null, 2)}
                    </pre>
                  </div>
                </div>
                {/* Enriched Data */}
                <div>
                  <h4 className="text-sm font-medium text-gray-900 mb-3">AI-Enriched Data</h4>
                  <div className="bg-green-50 rounded p-3">
                    <pre className="text-xs text-gray-700 whitespace-pre-wrap">
                      {JSON.stringify(item.enriched, null, 2)}
                    </pre>
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Results */}
      {results && (
        <div className="bg-white shadow rounded-lg p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-6">Pipeline Results</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="bg-blue-50 rounded-lg p-4">
              <div className="text-2xl font-bold text-blue-900">{results.totalRecords}</div>
              <div className="text-sm text-blue-700">Total Records</div>
            </div>
            <div className="bg-green-50 rounded-lg p-4">
              <div className="text-2xl font-bold text-green-900">{results.processedRecords}</div>
              <div className="text-sm text-green-700">Processed Records</div>
            </div>
            <div className="bg-yellow-50 rounded-lg p-4">
              <div className="text-2xl font-bold text-yellow-900">{results.errorCount}</div>
              <div className="text-sm text-yellow-700">Error Count</div>
            </div>
            <div className="bg-purple-50 rounded-lg p-4">
              <div className="text-2xl font-bold text-purple-900">{(results.avgConfidence * 100).toFixed(1)}%</div>
              <div className="text-sm text-purple-700">Avg Confidence</div>
            </div>
          </div>
          <div className="mt-6 p-4 bg-gray-50 rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <div className="text-sm font-medium text-gray-900">Total Processing Time</div>
                <div className="text-2xl font-bold text-gray-900">{results.processingTime}s</div>
              </div>
              <div className="text-right">
                <div className="text-sm font-medium text-green-900">Success Rate</div>
                <div className="text-2xl font-bold text-green-900">100%</div>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}

export default PipelineDemo
