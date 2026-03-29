import React, { useState } from 'react'
import toast from 'react-hot-toast'
import { 
  Cog6ToothIcon,
  ServerIcon,
  CloudIcon,
  BellIcon,
  ShieldCheckIcon
} from '@heroicons/react/24/outline'

const Settings = () => {
  const [activeTab, setActiveTab] = useState('general')
  const [settings, setSettings] = useState({
    general: {
      projectName: 'Product Catalog Pipeline',
      environment: 'Development',
      region: 'us-east-1',
      autoRefresh: true,
      refreshInterval: 30
    },
    aws: {
      accessKeyId: 'AKIAIOSFODNN7EXAMPLE',
      secretAccessKey: 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
      s3Bucket: 'product-catalog-dev-raw',
      lambdaTimeout: 300,
      lambdaMemory: 512
    },
    notifications: {
      emailAlerts: true,
      smsAlerts: false,
      errorNotifications: true,
      successNotifications: false,
      webhookUrl: ''
    },
    security: {
      encryptionEnabled: true,
      accessLogging: true,
      iamRoles: true,
      vpcIsolation: true
    }
  })

  const tabs = [
    { id: 'general', name: 'General', icon: Cog6ToothIcon },
    { id: 'aws', name: 'AWS Configuration', icon: CloudIcon },
    { id: 'notifications', name: 'Notifications', icon: BellIcon },
    { id: 'security', name: 'Security', icon: ShieldCheckIcon }
  ]

  const handleSettingChange = (category, field, value) => {
    setSettings(prev => ({
      ...prev,
      [category]: {
        ...prev[category],
        [field]: value
      }
    }))
  }

  const saveSettings = () => {
    toast.success('Settings saved successfully!')
  }

  const resetSettings = () => {
    toast('Settings reset to defaults')
  }

  const renderGeneralSettings = () => (
    <div className="space-y-6">
      <div>
        <label className="block text-sm font-medium text-gray-700">Project Name</label>
        <input
          type="text"
          value={settings.general.projectName}
          onChange={(e) => handleSettingChange('general', 'projectName', e.target.value)}
          className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
        />
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">Environment</label>
        <select
          value={settings.general.environment}
          onChange={(e) => handleSettingChange('general', 'environment', e.target.value)}
          className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
        >
          <option value="Development">Development</option>
          <option value="Staging">Staging</option>
          <option value="Production">Production</option>
        </select>
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">AWS Region</label>
        <select
          value={settings.general.region}
          onChange={(e) => handleSettingChange('general', 'region', e.target.value)}
          className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
        >
          <option value="us-east-1">US East (N. Virginia)</option>
          <option value="us-west-2">US West (Oregon)</option>
          <option value="eu-west-1">EU (Ireland)</option>
          <option value="ap-southeast-1">Asia Pacific (Singapore)</option>
        </select>
      </div>
      
      <div className="flex items-center">
        <input
          type="checkbox"
          checked={settings.general.autoRefresh}
          onChange={(e) => handleSettingChange('general', 'autoRefresh', e.target.checked)}
          className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
        />
        <label className="ml-2 block text-sm text-gray-900">
          Enable auto-refresh dashboard
        </label>
      </div>
      
      {settings.general.autoRefresh && (
        <div>
          <label className="block text-sm font-medium text-gray-700">Refresh Interval (seconds)</label>
          <input
            type="number"
            value={settings.general.refreshInterval}
            onChange={(e) => handleSettingChange('general', 'refreshInterval', parseInt(e.target.value))}
            min="10"
            max="300"
            className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          />
        </div>
      )}
    </div>
  )

  const renderAWSSettings = () => (
    <div className="space-y-6">
      <div>
        <label className="block text-sm font-medium text-gray-700">AWS Access Key ID</label>
        <input
          type="password"
          value={settings.aws.accessKeyId}
          onChange={(e) => handleSettingChange('aws', 'accessKeyId', e.target.value)}
          className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          placeholder="Enter your AWS Access Key ID"
        />
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">AWS Secret Access Key</label>
        <input
          type="password"
          value={settings.aws.secretAccessKey}
          onChange={(e) => handleSettingChange('aws', 'secretAccessKey', e.target.value)}
          className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          placeholder="Enter your AWS Secret Access Key"
        />
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">S3 Bucket Name</label>
        <input
          type="text"
          value={settings.aws.s3Bucket}
          onChange={(e) => handleSettingChange('aws', 's3Bucket', e.target.value)}
          className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          placeholder="product-catalog-dev-raw"
        />
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">Lambda Timeout (seconds)</label>
        <input
          type="number"
          value={settings.aws.lambdaTimeout}
          onChange={(e) => handleSettingChange('aws', 'lambdaTimeout', parseInt(e.target.value))}
          min="1"
          max="900"
          className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
        />
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">Lambda Memory (MB)</label>
        <input
          type="number"
          value={settings.aws.lambdaMemory}
          onChange={(e) => handleSettingChange('aws', 'lambdaMemory', parseInt(e.target.value))}
          min="128"
          max="3008"
          step="64"
          className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
        />
      </div>
    </div>
  )

  const renderNotificationSettings = () => (
    <div className="space-y-6">
      <div className="space-y-4">
        <h4 className="text-sm font-medium text-gray-900">Alert Channels</h4>
        
        <div className="flex items-center">
          <input
            type="checkbox"
            checked={settings.notifications.emailAlerts}
            onChange={(e) => handleSettingChange('notifications', 'emailAlerts', e.target.checked)}
            className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          />
          <label className="ml-2 block text-sm text-gray-900">
            Email alerts
          </label>
        </div>
        
        <div className="flex items-center">
          <input
            type="checkbox"
            checked={settings.notifications.smsAlerts}
            onChange={(e) => handleSettingChange('notifications', 'smsAlerts', e.target.checked)}
            className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          />
          <label className="ml-2 block text-sm text-gray-900">
            SMS alerts
          </label>
        </div>
      </div>
      
      <div className="space-y-4">
        <h4 className="text-sm font-medium text-gray-900">Notification Types</h4>
        
        <div className="flex items-center">
          <input
            type="checkbox"
            checked={settings.notifications.errorNotifications}
            onChange={(e) => handleSettingChange('notifications', 'errorNotifications', e.target.checked)}
            className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          />
          <label className="ml-2 block text-sm text-gray-900">
            Error notifications
          </label>
        </div>
        
        <div className="flex items-center">
          <input
            type="checkbox"
            checked={settings.notifications.successNotifications}
            onChange={(e) => handleSettingChange('notifications', 'successNotifications', e.target.checked)}
            className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          />
          <label className="ml-2 block text-sm text-gray-900">
            Success notifications
          </label>
        </div>
      </div>
      
      <div>
        <label className="block text-sm font-medium text-gray-700">Webhook URL</label>
        <input
          type="url"
          value={settings.notifications.webhookUrl}
          onChange={(e) => handleSettingChange('notifications', 'webhookUrl', e.target.value)}
          className="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-blue-500 focus:border-blue-500 sm:text-sm"
          placeholder="https://hooks.slack.com/services/..."
        />
        <p className="mt-1 text-xs text-gray-500">
          Send notifications to Slack or other webhook endpoints
        </p>
      </div>
    </div>
  )

  const renderSecuritySettings = () => (
    <div className="space-y-6">
      <div className="space-y-4">
        <h4 className="text-sm font-medium text-gray-900">Data Protection</h4>
        
        <div className="flex items-center">
          <input
            type="checkbox"
            checked={settings.security.encryptionEnabled}
            onChange={(e) => handleSettingChange('security', 'encryptionEnabled', e.target.checked)}
            className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          />
          <label className="ml-2 block text-sm text-gray-900">
            Enable encryption at rest and in transit
          </label>
        </div>
        
        <div className="flex items-center">
          <input
            type="checkbox"
            checked={settings.security.accessLogging}
            onChange={(e) => handleSettingChange('security', 'accessLogging', e.target.checked)}
            className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          />
          <label className="ml-2 block text-sm text-gray-900">
            Enable access logging
          </label>
        </div>
      </div>
      
      <div className="space-y-4">
        <h4 className="text-sm font-medium text-gray-900">Access Control</h4>
        
        <div className="flex items-center">
          <input
            type="checkbox"
            checked={settings.security.iamRoles}
            onChange={(e) => handleSettingChange('security', 'iamRoles', e.target.checked)}
            className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          />
          <label className="ml-2 block text-sm text-gray-900">
            Use IAM roles for least privilege access
          </label>
        </div>
        
        <div className="flex items-center">
          <input
            type="checkbox"
            checked={settings.security.vpcIsolation}
            onChange={(e) => handleSettingChange('security', 'vpcIsolation', e.target.checked)}
            className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
          />
          <label className="ml-2 block text-sm text-gray-900">
            Enable VPC isolation for database
          </label>
        </div>
      </div>
      
      <div className="bg-yellow-50 border border-yellow-200 rounded-md p-4">
        <div className="flex">
          <div className="flex-shrink-0">
            <ShieldCheckIcon className="h-5 w-5 text-yellow-400" aria-hidden="true" />
          </div>
          <div className="ml-3">
            <h3 className="text-sm font-medium text-yellow-800">Security Notice</h3>
            <div className="mt-2 text-sm text-yellow-700">
              <p>
                These settings affect the security posture of your pipeline. 
                Ensure you understand the implications before making changes.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  )

  const renderTabContent = () => {
    switch (activeTab) {
      case 'general':
        return renderGeneralSettings()
      case 'aws':
        return renderAWSSettings()
      case 'notifications':
        return renderNotificationSettings()
      case 'security':
        return renderSecuritySettings()
      default:
        return renderGeneralSettings()
    }
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-2xl font-bold text-gray-900">Settings</h1>
        <p className="mt-1 text-sm text-gray-600">
          Configure your product catalog pipeline settings
        </p>
      </div>

      <div className="bg-white shadow rounded-lg">
        {/* Tab Navigation */}
        <div className="border-b border-gray-200">
          <nav className="flex -mb-px px-6 space-x-8">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id)}
                className={`group inline-flex items-center py-4 px-1 border-b-2 font-medium text-sm ${
                  activeTab === tab.id
                    ? 'border-blue-500 text-blue-600'
                    : 'border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300'
                }`}
              >
                <tab.icon
                  className={`mr-2 h-5 w-5 ${
                    activeTab === tab.id ? 'text-blue-500' : 'text-gray-400 group-hover:text-gray-500'
                  }`}
                  aria-hidden="true"
                />
                {tab.name}
              </button>
            ))}
          </nav>
        </div>

        {/* Tab Content */}
        <div className="px-6 py-6">
          {renderTabContent()}
          
          {/* Action Buttons */}
          <div className="mt-8 flex justify-end space-x-3">
            <button
              onClick={resetSettings}
              className="inline-flex items-center px-4 py-2 border border-gray-300 shadow-sm text-sm font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              Reset to Defaults
            </button>
            <button
              onClick={saveSettings}
              className="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              Save Settings
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

export default Settings
