# Product Catalog Pipeline Web UI

A modern, responsive web interface for demonstrating the AI-powered product catalog ingestion pipeline.

## Features

- **🏠 Dashboard**: Real-time metrics and system overview
- **🚀 Pipeline Demo**: Interactive demonstration of the AI pipeline
- **📤 Data Upload**: Drag-and-drop file upload interface
- **📊 Monitoring**: Live system monitoring and performance metrics
- **⚙️ Settings**: Configuration management for the pipeline

## Technology Stack

- **React 18** - Modern UI framework
- **Vite** - Fast development build tool
- **Tailwind CSS** - Utility-first CSS framework
- **Heroicons** - Beautiful SVG icons
- **Recharts** - Data visualization library
- **React Hot Toast** - Elegant notifications

## Getting Started

### Prerequisites

- Node.js 18+ 
- npm or yarn

### Installation

1. Install dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm run dev
```

3. Open your browser and navigate to `http://localhost:3000`

## Available Scripts

- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run preview` - Preview production build
- `npm run test` - Run tests
- `npm run test:ui` - Run tests with UI
- `npm run lint` - Run ESLint

## Project Structure

```
src/
├── components/
│   └── Layout.jsx          # Main layout component
├── pages/
│   ├── Dashboard.jsx       # Dashboard page
│   ├── PipelineDemo.jsx   # Pipeline demonstration
│   ├── DataUpload.jsx     # File upload interface
│   ├── Monitoring.jsx     # System monitoring
│   └── Settings.jsx       # Configuration settings
├── App.jsx                # Main application component
├── main.jsx              # Application entry point
└── index.css              # Global styles
```

## Features Overview

### Dashboard
- Real-time system metrics
- Processing volume charts
- Data quality scores
- Recent activity feed
- Quick action buttons

### Pipeline Demo
- Step-by-step pipeline visualization
- Sample data transformation examples
- Interactive controls
- Real-time progress tracking
- Before/after data comparison

### Data Upload
- Drag-and-drop file upload
- File format validation
- Upload progress tracking
- Sample CSV download
- Upload history

### Monitoring
- System health indicators
- Performance metrics charts
- Resource utilization
- Alert notifications
- Time range selection

### Settings
- General configuration
- AWS service settings
- Notification preferences
- Security options

## Configuration

The UI connects to the backend AWS services through configuration. Update the settings page to configure:

- AWS region and credentials
- S3 bucket names
- Lambda function settings
- Notification preferences

## Styling

The UI uses Tailwind CSS for styling with a custom design system:

- **Color Palette**: Blue, green, purple, and yellow accents
- **Typography**: Inter font family
- **Components**: Reusable UI components with consistent styling
- **Responsive**: Mobile-first responsive design

## Icons

Icons are provided by Heroicons, ensuring a consistent and modern look throughout the application.

## Charts and Data Visualization

Recharts is used for creating interactive charts:
- Line charts for time series data
- Bar charts for categorical data
- Area charts for volume visualization
- Custom tooltips and legends

## Deployment

### Build for Production

```bash
npm run build
```

The build artifacts will be in the `dist` directory.

### Preview Production Build

```bash
npm run preview
```

## Environment Variables

Create a `.env.local` file for local development:

```env
VITE_API_BASE_URL=http://localhost:3001
VITE_AWS_REGION=us-east-1
VITE_S3_BUCKET=product-catalog-dev-raw
```

## Contributing

1. Follow the existing code style
2. Use meaningful component names
3. Add comments for complex logic
4. Test new features
5. Update documentation

## Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## Performance

The UI is optimized for performance:
- Code splitting by route
- Lazy loading of components
- Optimized bundle size
- Efficient re-renders

## Accessibility

The UI follows WCAG 2.1 guidelines:
- Semantic HTML structure
- Keyboard navigation support
- Screen reader compatibility
- High contrast ratios
- Focus indicators

## Troubleshooting

### Common Issues

1. **Port already in use**: Change the port in `vite.config.js`
2. **Dependencies not found**: Run `npm install`
3. **Build fails**: Check for syntax errors in the code
4. **API errors**: Verify backend configuration

### Debug Mode

Enable debug mode by adding `?debug=true` to the URL to see additional logging.

## License

MIT License - see LICENSE file for details.
