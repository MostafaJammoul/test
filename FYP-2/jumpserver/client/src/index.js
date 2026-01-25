/**
 * DFIR JumpServer - Fabric Gateway Client
 *
 * Zero Trust gateway for blockchain-based Digital Forensics chain-of-custody system.
 * Provides sole entry point for all blockchain and IPFS interactions.
 *
 * Features:
 * - Fabric Gateway SDK integration
 * - Passwordless MFA (WebAuthn)
 * - Role-based access control (RBAC)
 * - IPFS cluster integration
 * - Comprehensive audit logging
 */

import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { createLogger, format, transports } from 'winston';

import fabricGateway from './fabric/gateway.js';
import evidenceRoutes from './routes/evidence.js';
import authRoutes from './routes/auth.js';
import ipfsRoutes from './routes/ipfs.js';
import { authMiddleware } from './middleware/auth.js';
import { rbacMiddleware } from './middleware/rbac.js';
import { auditMiddleware } from './middleware/audit.js';

// Load environment variables
dotenv.config();

// Create Express app
const app = express();
const PORT = process.env.PORT || 3000;

// ============================================================================
// Logger Configuration
// ============================================================================

export const logger = createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: format.combine(
    format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    format.errors({ stack: true }),
    format.splat(),
    format.json()
  ),
  defaultMeta: { service: 'jumpserver-gateway' },
  transports: [
    new transports.File({ filename: 'logs/error.log', level: 'error' }),
    new transports.File({ filename: 'logs/combined.log' }),
    new transports.File({ filename: 'logs/audit.log', level: 'info' })
  ]
});

// Console logging in development
if (process.env.NODE_ENV !== 'production') {
  logger.add(new transports.Console({
    format: format.combine(
      format.colorize(),
      format.simple()
    )
  }));
}

// ============================================================================
// Security Middleware
// ============================================================================

// Helmet for security headers
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:', 'https:'],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// CORS configuration (restrict in production)
const corsOptions = {
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true,
  optionsSuccessStatus: 200
};
app.use(cors(corsOptions));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 requests per windowMs
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/', limiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// HTTP request logging
app.use(morgan('combined', {
  stream: {
    write: (message) => logger.info(message.trim())
  }
}));

// ============================================================================
// Routes
// ============================================================================

// Health check (no auth required)
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'jumpserver-gateway',
    version: '1.0.0'
  });
});

// Authentication routes (no prior auth required)
app.use('/api/auth', authRoutes);

// Protected routes (require authentication and RBAC)
app.use('/api/evidence', authMiddleware, rbacMiddleware, auditMiddleware, evidenceRoutes);
app.use('/api/ipfs', authMiddleware, rbacMiddleware, auditMiddleware, ipfsRoutes);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.method} ${req.path} not found`
  });
});

// Global error handler
app.use((err, req, res, next) => {
  logger.error('Unhandled error:', {
    error: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method
  });

  res.status(err.status || 500).json({
    error: 'Internal Server Error',
    message: process.env.NODE_ENV === 'production'
      ? 'An error occurred processing your request'
      : err.message
  });
});

// ============================================================================
// Startup
// ============================================================================

async function startServer() {
  try {
    // Initialize Fabric Gateway connection
    logger.info('Connecting to Fabric Gateway...');
    await fabricGateway.connect();
    logger.info('Fabric Gateway connected successfully');

    // Start Express server
    app.listen(PORT, () => {
      logger.info(`JumpServer Gateway listening on port ${PORT}`);
      logger.info(`Environment: ${process.env.NODE_ENV || 'development'}`);
      logger.info(`API endpoint: http://localhost:${PORT}/api`);
    });

  } catch (error) {
    logger.error('Failed to start server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  await fabricGateway.disconnect();
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('SIGINT signal received: closing HTTP server');
  await fabricGateway.disconnect();
  process.exit(0);
});

// Start the server
startServer();

export default app;
