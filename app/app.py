#!/usr/bin/env python3
"""
Sample microservice with OpenTelemetry tracing instrumentation.
This service automatically generates traces for every HTTP request.
"""

import os
import time
import random
import logging
import json
import uuid
import signal
import sys
from datetime import datetime
from flask import Flask, jsonify, request, g
from opentelemetry import trace
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.resources import Resource
from prometheus_client import Counter, Histogram, Gauge, generate_latest

class StructuredLogger:
    """Custom structured logger that outputs JSON logs with correlation IDs."""
    
    def __init__(self, name):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(logging.INFO)
        
        # Remove any existing handlers
        for handler in self.logger.handlers[:]:
            self.logger.removeHandler(handler)
        
        # Create JSON formatter
        handler = logging.StreamHandler()
        handler.setFormatter(self._get_json_formatter())
        self.logger.addHandler(handler)
        self.logger.propagate = False
    
    def _get_json_formatter(self):
        class JSONFormatter(logging.Formatter):
            def format(self, record):
                log_entry = {
                    "timestamp": datetime.utcnow().isoformat() + "Z",
                    "level": record.levelname,
                    "message": record.getMessage(),
                    "service": "sample-service",
                    "version": "1.0.0"
                }
                
                # Add correlation ID if available (only within request context)
                try:
                    if hasattr(g, 'correlation_id'):
                        log_entry["correlation_id"] = g.correlation_id
                except RuntimeError:
                    # Outside of application context, no correlation ID available
                    pass
                
                # Add trace ID if available
                try:
                    span = trace.get_current_span()
                    if span and span.is_recording():
                        trace_ctx = span.get_span_context()
                        log_entry["trace_id"] = format(trace_ctx.trace_id, '032x')
                        log_entry["span_id"] = format(trace_ctx.span_id, '016x')
                except Exception:
                    # Trace context not available
                    pass
                
                # Add any extra fields from the log record
                if hasattr(record, 'extra_fields'):
                    log_entry.update(record.extra_fields)
                
                # Add exception info if present
                if record.exc_info:
                    log_entry["exception"] = self.formatException(record.exc_info)
                
                return json.dumps(log_entry)
        
        return JSONFormatter()
    
    def info(self, message, **kwargs):
        extra = {"extra_fields": kwargs} if kwargs else None
        self.logger.info(message, extra=extra)
    
    def warning(self, message, **kwargs):
        extra = {"extra_fields": kwargs} if kwargs else None
        self.logger.warning(message, extra=extra)
    
    def error(self, message, **kwargs):
        extra = {"extra_fields": kwargs} if kwargs else None
        self.logger.error(message, extra=extra)
    
    def debug(self, message, **kwargs):
        extra = {"extra_fields": kwargs} if kwargs else None
        self.logger.debug(message, extra=extra)

# Configure structured logging
logger = StructuredLogger(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter('sample_service_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('sample_service_request_duration_seconds', 'Request duration in seconds', ['method', 'endpoint'])
SERVICE_UP = Gauge('sample_service_up', 'Service is up')

def setup_tracing():
    """Configure OpenTelemetry tracing."""
    
    resource = Resource.create({
        "service.name": os.getenv("OTEL_SERVICE_NAME", "sample-service"),
        "service.version": "1.0.0",
        "deployment.environment": "demo"
    })
    
    trace.set_tracer_provider(TracerProvider(resource=resource))
    
    # Configure tracing exporter
    otlp_endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT")
    if otlp_endpoint:
        try:
            from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
            otlp_exporter = OTLPSpanExporter(endpoint=otlp_endpoint)
            logger.info(f"OTLP tracing configured: {otlp_endpoint}")
        except Exception as e:
            logger.warning(f"Failed to configure OTLP exporter: {e}")
            # Use a no-op exporter instead of console
            from opentelemetry.sdk.trace.export import SpanExporter
            class NoOpExporter(SpanExporter):
                def export(self, spans):
                    return True
                def shutdown(self):
                    pass
            otlp_exporter = NoOpExporter()
    else:
        logger.info("No OTEL_EXPORTER_OTLP_ENDPOINT configured, tracing disabled")
        # Use a no-op exporter
        from opentelemetry.sdk.trace.export import SpanExporter
        class NoOpExporter(SpanExporter):
            def export(self, spans):
                return True
            def shutdown(self):
                pass
        otlp_exporter = NoOpExporter()
    
    span_processor = BatchSpanProcessor(otlp_exporter)
    trace.get_tracer_provider().add_span_processor(span_processor)
    
    return trace.get_tracer(__name__)

app = Flask(__name__)
tracer = setup_tracing()

# Disable Flask's default access logging to avoid duplication with our structured logs
logging.getLogger('werkzeug').setLevel(logging.WARNING)

# Auto-instrument Flask
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

SERVICE_UP.set(1)

@app.before_request
def before_request():
    """Generate correlation ID for each request."""
    g.correlation_id = str(uuid.uuid4())
    g.start_time = time.time()
    
    logger.info("Request started", 
                method=request.method,
                path=request.path,
                remote_addr=request.remote_addr,
                user_agent=request.headers.get('User-Agent', ''))

@app.after_request
def after_request(response):
    """Log request completion."""
    duration = time.time() - g.start_time
    
    logger.info("Request completed",
                method=request.method,
                path=request.path,
                status_code=response.status_code,
                duration_ms=round(duration * 1000, 2),
                response_size=response.content_length or 0)
    
    # Add correlation ID to response headers for client debugging
    response.headers['X-Correlation-ID'] = g.correlation_id
    return response

@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "sample-service"}), 200

@app.route('/ready')
def ready():
    return jsonify({"status": "ready", "service": "sample-service"}), 200

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': 'text/plain; charset=utf-8'}

@app.route('/')
def home():
    start_time = time.time()
    endpoint = '/'
    method = request.method
    
    with tracer.start_as_current_span("home_request") as span:
        span.set_attribute("http.method", method)
        span.set_attribute("http.url", endpoint)
        
        response_data = {
            "message": "Welcome to the Sample Service!",
            "version": "1.0.0",
            "service": "sample-service",
            "endpoints": {
                "health": "/health",
                "ready": "/ready", 
                "metrics": "/metrics",
                "users": "/api/users",
                "slow": "/api/slow",
                "error": "/api/error"
            }
        }
        
        duration = time.time() - start_time
        REQUEST_DURATION.labels(method=method, endpoint=endpoint).observe(duration)
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='200').inc()
        span.set_attribute("http.status_code", 200)
        
        return jsonify(response_data), 200

@app.route('/api/users')
def list_users():
    start_time = time.time()
    endpoint = '/api/users'
    method = request.method
    
    with tracer.start_as_current_span("list_users") as span:
        span.set_attribute("http.method", method)
        span.set_attribute("http.url", endpoint)
        
        logger.info("Fetching user list", operation="list_users")
        
        # Simulate some processing time
        processing_time = random.uniform(0.1, 0.5)
        time.sleep(processing_time)
        span.set_attribute("processing.duration_ms", processing_time * 1000)
        
        # Simulate occasional slow responses
        is_slow = random.random() < 0.1  # 10% chance
        if is_slow:
            slow_time = random.uniform(1.0, 3.0)
            time.sleep(slow_time)
            span.set_attribute("slow_response", True)
            span.set_attribute("slow.duration_ms", slow_time * 1000)
            logger.warning("Slow response detected", 
                          operation="list_users",
                          slow_duration_ms=round(slow_time * 1000, 2),
                          reason="database_slow_query")
        
        # Generate user data
        user_count = random.randint(3, 10)
        users = [
            {"id": i, "name": f"User {i}", "email": f"user{i}@example.com"}
            for i in range(1, user_count)
        ]
        
        duration = time.time() - start_time
        REQUEST_DURATION.labels(method=method, endpoint=endpoint).observe(duration)
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='200').inc()
        span.set_attribute("http.status_code", 200)
        span.set_attribute("user.count", len(users))
        
        logger.info("User list retrieved successfully",
                   operation="list_users",
                   user_count=len(users),
                   processing_time_ms=round(processing_time * 1000, 2),
                   total_duration_ms=round(duration * 1000, 2),
                   was_slow=is_slow)
        
        return jsonify({"users": users}), 200

@app.route('/api/users/<int:user_id>')
def get_user(user_id):
    start_time = time.time()
    endpoint = f'/api/users/{user_id}'
    method = request.method
    
    with tracer.start_as_current_span("get_user") as span:
        span.set_attribute("http.method", method)
        span.set_attribute("http.url", endpoint)
        span.set_attribute("user.id", user_id)
        
        logger.info("Fetching user by ID", 
                   operation="get_user",
                   user_id=user_id)
        
        # Simulate database lookup
        db_lookup_time = random.uniform(0.05, 0.2)
        time.sleep(db_lookup_time)
        
        logger.debug("Database lookup completed",
                    operation="get_user",
                    user_id=user_id,
                    db_duration_ms=round(db_lookup_time * 1000, 2))
        
        if user_id > 1000:
            duration = time.time() - start_time
            REQUEST_DURATION.labels(method=method, endpoint='/api/users/{id}').observe(duration)
            REQUEST_COUNT.labels(method=method, endpoint='/api/users/{id}', status='404').inc()
            span.set_attribute("http.status_code", 404)
            span.set_attribute("error", True)
            
            logger.warning("User not found",
                          operation="get_user",
                          user_id=user_id,
                          error_type="not_found",
                          duration_ms=round(duration * 1000, 2))
            
            return jsonify({"error": "User not found"}), 404
        
        user = {
            "id": user_id,
            "name": f"User {user_id}",
            "email": f"user{user_id}@example.com",
            "created_at": "2023-01-01T00:00:00Z"
        }
        
        duration = time.time() - start_time
        REQUEST_DURATION.labels(method=method, endpoint='/api/users/{id}').observe(duration)
        REQUEST_COUNT.labels(method=method, endpoint='/api/users/{id}', status='200').inc()
        span.set_attribute("http.status_code", 200)
        
        logger.info("User retrieved successfully",
                   operation="get_user",
                   user_id=user_id,
                   user_email=user["email"],
                   db_duration_ms=round(db_lookup_time * 1000, 2),
                   total_duration_ms=round(duration * 1000, 2))
        
        return jsonify(user), 200

@app.route('/api/slow')
def slow_endpoint():
    start_time = time.time()
    endpoint = '/api/slow'
    method = request.method
    
    with tracer.start_as_current_span("slow_endpoint") as span:
        span.set_attribute("http.method", method)
        span.set_attribute("http.url", endpoint)
        
        # Intentionally slow endpoint
        slow_time = random.uniform(2.0, 5.0)
        
        logger.info("Starting slow operation",
                   operation="slow_endpoint",
                   expected_duration_ms=round(slow_time * 1000, 2),
                   operation_type="heavy_computation")
        
        # Simulate different types of slow operations
        slow_types = ["database_query", "external_api_call", "heavy_computation", "file_processing"]
        slow_type = random.choice(slow_types)
        
        time.sleep(slow_time)
        span.set_attribute("slow.duration_ms", slow_time * 1000)
        span.set_attribute("slow.type", slow_type)
        
        response_data = {
            "message": "This is a slow endpoint for testing monitoring",
            "processing_time": slow_time,
            "operation_type": slow_type
        }
        
        duration = time.time() - start_time
        REQUEST_DURATION.labels(method=method, endpoint=endpoint).observe(duration)
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='200').inc()
        span.set_attribute("http.status_code", 200)
        
        logger.info("Slow operation completed",
                   operation="slow_endpoint",
                   operation_type=slow_type,
                   actual_duration_ms=round(duration * 1000, 2),
                   slow_duration_ms=round(slow_time * 1000, 2))
        
        return jsonify(response_data), 200

@app.route('/api/error')
def error_endpoint():
    """Always returns an error - predictable for testing."""
    start_time = time.time()
    endpoint = '/api/error'
    method = request.method
    
    with tracer.start_as_current_span("error_endpoint") as span:
        span.set_attribute("http.method", method)
        span.set_attribute("http.url", endpoint)
        span.set_attribute("http.status_code", 500)
        span.set_attribute("error", True)
        
        error_types = ["database_timeout", "external_service_down", "memory_limit", "invalid_state"]
        error_type = random.choice(error_types)
        error_id = str(uuid.uuid4())[:8]
        
        exception = Exception(f"Simulated {error_type} error")
        span.record_exception(exception)
        
        duration = time.time() - start_time
        REQUEST_DURATION.labels(method=method, endpoint=endpoint).observe(duration)
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='500').inc()
        
        logger.error("Predictable error endpoint triggered",
                    operation="error_endpoint",
                    error_type=error_type,
                    error_id=error_id,
                    always_fails=True,
                    duration_ms=round(duration * 1000, 2),
                    stack_trace=True)
        
        return jsonify({
            "error": "Internal server error", 
            "message": "This endpoint always returns an error for testing",
            "error_type": error_type,
            "error_id": error_id
        }), 500

@app.route('/api/flaky')
def flaky_endpoint():
    """Sometimes returns an error - realistic for SRE scenarios."""
    start_time = time.time()
    endpoint = '/api/flaky'
    method = request.method
    
    with tracer.start_as_current_span("flaky_endpoint") as span:
        span.set_attribute("http.method", method)
        span.set_attribute("http.url", endpoint)
        
        error_chance = random.random()
        will_error = error_chance < 0.3  # 30% chance of error
        
        logger.info("Processing flaky endpoint",
                   operation="flaky_endpoint",
                   error_probability=0.3,
                   random_value=round(error_chance, 3))
        
        # 30% chance of returning an error
        if will_error:
            duration = time.time() - start_time
            REQUEST_DURATION.labels(method=method, endpoint=endpoint).observe(duration)
            REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='500').inc()
            span.set_attribute("http.status_code", 500)
            span.set_attribute("error", True)
            
            error_types = ["network_timeout", "service_unavailable", "rate_limit", "circuit_breaker"]
            error_type = random.choice(error_types)
            error_id = str(uuid.uuid4())[:8]
            
            exception = Exception(f"Intermittent {error_type} error")
            span.record_exception(exception)
            
            logger.error("Flaky endpoint error occurred",
                        operation="flaky_endpoint",
                        error_type=error_type,
                        error_id=error_id,
                        duration_ms=round(duration * 1000, 2),
                        stack_trace=True)
            
            return jsonify({
                "error": "Service temporarily unavailable", 
                "message": "This endpoint fails intermittently for realistic testing",
                "error_type": error_type,
                "error_id": error_id
            }), 500
        
        duration = time.time() - start_time
        REQUEST_DURATION.labels(method=method, endpoint=endpoint).observe(duration)
        REQUEST_COUNT.labels(method=method, endpoint=endpoint, status='200').inc()
        span.set_attribute("http.status_code", 200)
        
        logger.info("Flaky endpoint succeeded",
                   operation="flaky_endpoint",
                   outcome="success",
                   duration_ms=round(duration * 1000, 2))
        
        return jsonify({"message": "Success! The flaky endpoint worked this time."}), 200

def signal_handler(sig, frame):
    """Handle graceful shutdown on SIGTERM/SIGINT."""
    logger.info("Shutdown signal received",
                signal=signal.Signals(sig).name,
                graceful=True)
    
    # Set service as down for health checks
    SERVICE_UP.set(0)
    
    logger.info("Sample service shutting down gracefully",
                service="sample-service",
                final_message=True)
    
    sys.exit(0)

if __name__ == '__main__':
    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    
    logger.info("Starting sample service",
                service="sample-service", 
                version="1.0.0",
                port=8080,
                debug=False,
                environment=os.getenv("ENV", "production"))
    
    try:
        app.run(host='0.0.0.0', port=8080, debug=False)
    except Exception as e:
        logger.error("Failed to start service",
                    service="sample-service",
                    error=str(e),
                    error_type=type(e).__name__)
        raise 