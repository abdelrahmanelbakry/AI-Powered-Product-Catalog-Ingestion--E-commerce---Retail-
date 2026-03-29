import React, { useState, useRef } from 'react'
import toast from 'react-hot-toast'
import { 
  CloudArrowUpIcon,
  DocumentTextIcon,
  CheckCircleIcon,
  ExclamationTriangleIcon
} from '@heroicons/react/24/outline'

const DataUpload = () => {
  const [dragActive, setDragActive] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [uploadedFiles, setUploadedFiles] = useState([])
  const [selectedFile, setSelectedFile] = useState(null)
  const fileInputRef = useRef(null)

  const sampleCSV = `product_name,price,description,category,brand,color
Nike Air Max 270,$129.99,Comfortable running shoes with air cushioning,Footwear,Nike,Black
Adidas Ultraboost 22,$159.99,High-performance running shoes,Footwear,Adidas,White
Levi's 501 Jeans,$89.99,Classic straight fit jeans,Clothing,Levi's,Blue
Apple iPhone 14,$999.99,Latest smartphone with advanced features,Electronics,Apple,Space Gray
Sony WH-1000XM4,$349.99,Premium noise-cancelling headphones,Electronics,Sony,Black`

  const handleDrag = (e) => {
    e.preventDefault()
    e.stopPropagation()
    if (e.type === "dragenter" || e.type === "dragover") {
      setDragActive(true)
    } else if (e.type === "dragleave") {
      setDragActive(false)
    }
  }

  const handleDrop = (e) => {
    e.preventDefault()
    e.stopPropagation()
    setDragActive(false)
    
    if (e.dataTransfer.files && e.dataTransfer.files[0]) {
      handleFile(e.dataTransfer.files[0])
    }
  }

  const handleChange = (e) => {
    e.preventDefault()
    if (e.target.files && e.target.files[0]) {
      handleFile(e.target.files[0])
    }
  }

  const handleFile = (file) => {
    // Validate file type
    const validTypes = ['text/csv', 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']
    if (!validTypes.includes(file.type)) {
      toast.error('Please upload a CSV or Excel file')
      return
    }

    // Validate file size (max 10MB)
    if (file.size > 10 * 1024 * 1024) {
      toast.error('File size must be less than 10MB')
      return
    }

    setSelectedFile(file)
    toast.success(`File "${file.name}" selected`)
  }

  const uploadFile = async () => {
    if (!selectedFile) {
      toast.error('Please select a file first')
      return
    }

    setUploading(true)
    
    // Simulate file upload
    await new Promise(resolve => setTimeout(resolve, 2000))
    
    const uploadedFile = {
      id: Date.now(),
      name: selectedFile.name,
      size: selectedFile.size,
      type: selectedFile.type,
      uploadedAt: new Date().toISOString(),
      status: 'uploaded',
      records: Math.floor(Math.random() * 1000) + 100
    }

    setUploadedFiles(prev => [uploadedFile, ...prev])
    setSelectedFile(null)
    setUploading(false)
    
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
    
    toast.success(`File "${uploadedFile.name}" uploaded successfully!`)
  }

  const downloadSample = () => {
    const blob = new Blob([sampleCSV], { type: 'text/csv' })
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'sample_products.csv'
    document.body.appendChild(a)
    a.click()
    window.URL.revokeObjectURL(url)
    document.body.removeChild(a)
    toast.success('Sample CSV downloaded')
  }

  const formatFileSize = (bytes) => {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleString()
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Data Upload</h1>
        <p className="mt-1 text-sm text-gray-600">
          Upload product catalog files (CSV or Excel) for AI processing
        </p>
      </div>

      {/* Upload Area */}
      <div className="bg-white shadow rounded-lg p-6">
        <div className="mb-4">
          <h3 className="text-lg font-medium text-gray-900">Upload File</h3>
          <p className="text-sm text-gray-500 mt-1">
            Drag and drop your file here, or click to browse
          </p>
        </div>
        
        <div
          className={`relative border-2 border-dashed rounded-lg p-6 text-center transition-colors ${
            dragActive
              ? 'border-blue-500 bg-blue-50'
              : 'border-gray-300 hover:border-gray-400'
          }`}
          onDragEnter={handleDrag}
          onDragLeave={handleDrag}
          onDragOver={handleDrag}
          onDrop={handleDrop}
        >
          <input
            ref={fileInputRef}
            type="file"
            className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
            onChange={handleChange}
            accept=".csv,.xlsx,.xls"
          />
          
          <CloudArrowUpIcon className="mx-auto h-12 w-12 text-gray-400" />
          <div className="mt-4">
            <label className="cursor-pointer">
              <span className="text-blue-600 font-medium hover:text-blue-500">
                Upload a file
              </span>
              <span className="text-gray-600"> or drag and drop</span>
            </label>
            <p className="text-xs text-gray-500 mt-1">
              CSV, XLSX, XLS up to 10MB
            </p>
          </div>
        </div>

        {selectedFile && (
          <div className="mt-4 p-4 bg-gray-50 rounded-lg">
            <div className="flex items-center justify-between">
              <div className="flex items-center">
                <DocumentTextIcon className="h-8 w-8 text-gray-400 mr-3" />
                <div>
                  <p className="text-sm font-medium text-gray-900">{selectedFile.name}</p>
                  <p className="text-xs text-gray-500">{formatFileSize(selectedFile.size)}</p>
                </div>
              </div>
              <button
                onClick={uploadFile}
                disabled={uploading}
                className="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50"
              >
                {uploading ? 'Uploading...' : 'Upload'}
              </button>
            </div>
          </div>
        )}

        <div className="mt-4 flex justify-center">
          <button
            onClick={downloadSample}
            className="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <DocumentTextIcon className="h-4 w-4 mr-2" />
            Download Sample CSV
          </button>
        </div>
      </div>

      {/* Uploaded Files */}
      <div className="bg-white shadow rounded-lg">
        <div className="px-6 py-4 border-b border-gray-200">
          <h3 className="text-lg font-medium text-gray-900">Uploaded Files</h3>
        </div>
        <div className="overflow-hidden">
          {uploadedFiles.length === 0 ? (
            <div className="px-6 py-12 text-center">
              <DocumentTextIcon className="mx-auto h-12 w-12 text-gray-400" />
              <h3 className="mt-2 text-sm font-medium text-gray-900">No files uploaded</h3>
              <p className="mt-1 text-sm text-gray-500">
                Upload your first product catalog file to get started
              </p>
            </div>
          ) : (
            <ul className="divide-y divide-gray-200">
              {uploadedFiles.map((file) => (
                <li key={file.id} className="px-6 py-4">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center">
                      <div className="flex-shrink-0">
                        {file.status === 'uploaded' ? (
                          <CheckCircleIcon className="h-8 w-8 text-green-500" />
                        ) : (
                          <ExclamationTriangleIcon className="h-8 w-8 text-yellow-500" />
                        )}
                      </div>
                      <div className="ml-4">
                        <div className="text-sm font-medium text-gray-900">{file.name}</div>
                        <div className="text-sm text-gray-500">
                          {formatFileSize(file.size)} • {file.records} records • {formatDate(file.uploadedAt)}
                        </div>
                      </div>
                    </div>
                    <div className="flex items-center space-x-2">
                      <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        file.status === 'uploaded' 
                          ? 'bg-green-100 text-green-800' 
                          : 'bg-yellow-100 text-yellow-800'
                      }`}>
                        {file.status === 'uploaded' ? 'Processed' : 'Processing'}
                      </span>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>

      {/* File Format Guidelines */}
      <div className="bg-white shadow rounded-lg p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">File Format Guidelines</h3>
        <div className="space-y-4">
          <div>
            <h4 className="text-sm font-medium text-gray-900 mb-2">Required Columns</h4>
            <div className="bg-gray-50 rounded p-3">
              <code className="text-sm text-gray-700">
                product_name (required)<br />
                price (optional)<br />
                description (optional)<br />
                category (optional)<br />
                brand (optional)<br />
                color (optional)<br />
                size (optional)
              </code>
            </div>
          </div>
          
          <div>
            <h4 className="text-sm font-medium text-gray-900 mb-2">Supported Formats</h4>
            <ul className="text-sm text-gray-600 space-y-1">
              <li>• CSV files with comma-separated values</li>
              <li>• Excel files (.xlsx, .xls)</li>
              <li>• Maximum file size: 10MB</li>
              <li>• Maximum records: 10,000 per file</li>
            </ul>
          </div>

          <div>
            <h4 className="text-sm font-medium text-gray-900 mb-2">AI Enhancement Features</h4>
            <ul className="text-sm text-gray-600 space-y-1">
              <li>• Automatic brand and category extraction</li>
              <li>• Product name normalization</li>
              <li>• Duplicate detection</li>
              <li>• Confidence scoring</li>
              <li>• Attribute enrichment (color, size, material)</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  )
}

export default DataUpload
