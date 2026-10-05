use std::io::{Read, Write};
use std::net::TcpListener;
use std::thread;

/// Serves one loopback HTTP response and returns the raw request it received.
pub fn serve(status: &str, body: &str) -> (String, thread::JoinHandle<Vec<u8>>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let status = status.to_string();
    let body = body.to_string();
    let handle = thread::spawn(move || {
        let (mut stream, _) = listener.accept().unwrap();
        let mut request = Vec::new();
        let mut chunk = [0u8; 4096];
        loop {
            let count = stream.read(&mut chunk).unwrap();
            if count == 0 {
                break;
            }
            request.extend_from_slice(&chunk[..count]);
            if let Some(length) = content_length(&request) {
                if request
                    .windows(4)
                    .position(|part| part == b"\r\n\r\n")
                    .is_some_and(|header_end| request.len() >= header_end + 4 + length)
                {
                    break;
                }
            }
        }
        write!(
            stream,
            "HTTP/1.1 {status}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
            body.len()
        )
        .unwrap();
        request
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
