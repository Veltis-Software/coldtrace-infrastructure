package com.acme.coldtrace.shared.infrastructure;

import com.acme.coldtrace.shared.CorrelationIds;
import jakarta.servlet.*;
import jakarta.servlet.http.*;
import java.io.IOException;
import org.slf4j.MDC;

public class CorrelationFilter implements Filter {
  public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
      throws IOException, ServletException {
    var request = (HttpServletRequest) req;
    var id = CorrelationIds.sanitize(request.getHeader("X-Correlation-Id"));
    request.setAttribute("correlationId", id);
    ((HttpServletResponse) res).setHeader("X-Correlation-Id", id);
    try {
      MDC.put("correlationId", id);
      chain.doFilter(req, res);
    } finally {
      MDC.remove("correlationId");
    }
  }
}
