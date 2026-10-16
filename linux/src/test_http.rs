use std::io::{Read, Write};
use std::net::{TcpListener, TcpStream};
use std::thread;
use std::time::{Duration, Instant};

// A failed request preparation must fail its fixture instead of leaving a
// join blocked forever. Each accepted connection is bounded as well.
fn accept(listener: TcpListener) -> TcpStream {
    listener.set_nonblocking(true).unwrap();
    let deadline = Instant::now() + Duration::from_secs(5);
    loop {
        match listener.accept() {
            Ok((stream, _)) => {
                stream
                    .set_read_timeout(Some(Duration::from_secs(5)))
                    .unwrap();
                stream
                    .set_write_timeout(Some(Duration::from_secs(5)))
                    .unwrap();
                return stream;
            }
            Err(error)
                if error.kind() == std::io::ErrorKind::WouldBlock && Instant::now() < deadline =>
            {
                thread::sleep(Duration::from_millis(5))
            }
            Err(error) => panic!("HTTP fixture did not receive a request: {error}"),
        }
    }
}

/// Serves one loopback HTTP response and returns the raw request it received.
pub fn serve(status: &str, body: &str) -> (String, thread::JoinHandle<Vec<u8>>) {
    serve_with_type(status, "application/json", body)
}

pub fn serve_with_type(
    status: &str,
    content_type: &str,
    body: &str,
) -> (String, thread::JoinHandle<Vec<u8>>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let status = status.to_string();
    let body = body.to_string();
    let content_type = content_type.to_string();
    let handle = thread::spawn(move || {
        let mut stream = accept(listener);
        let mut request = Vec::new();
        let mut chunk = [0u8; 4096];
        loop {
            let count = stream.read(&mut chunk).unwrap();
            if count == 0 {
                break;
            }
            request.extend_from_slice(&chunk[..count]);
            let header_end = request.windows(4).position(|part| part == b"\r\n\r\n");
            // A request without a body (GET) ends with its headers.
            let length = content_length(&request).unwrap_or(0);
            if header_end.is_some_and(|header_end| request.len() >= header_end + 4 + length) {
                break;
            }
        }
        let _ = write!(
            stream,
            "HTTP/1.1 {status}\r\nContent-Type: {content_type}\r\nLocation: /redirect-must-not-be-followed\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
            body.len()
        );
        request
    });
    (format!("http://{address}"), handle)
}

/// Accepts one request and never answers, like a provider behind a network
/// that dropped mid-request. Returns once the client has given up.
pub fn serve_without_answer() -> (String, thread::JoinHandle<()>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let handle = thread::spawn(move || {
        let mut stream = accept(listener);
        let mut chunk = [0u8; 4096];
        while matches!(stream.read(&mut chunk), Ok(count) if count > 0) {}
    });
    (format!("http://{address}"), handle)
}

fn content_length(request: &[u8]) -> Option<usize> {
    let text = String::from_utf8_lossy(request);
    text.lines().find_map(|line| {
        line.to_ascii_lowercase()
            .strip_prefix("content-length: ")
            .and_then(|value| value.trim().parse().ok())
    })
}
