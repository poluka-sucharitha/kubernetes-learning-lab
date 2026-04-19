# OSI Model (Networking Basics)

The **OSI (Open Systems Interconnection) Model** explains how network communication happens by dividing it into **7 layers**. Each layer has a specific responsibility in sending data from one computer to another.

```
7  Application
6  Presentation
5  Session
4  Transport
3  Network
2  Data Link
1  Physical
```

> **Easy Way to Remember:** All People Seem To Need Data Processing

---

## OSI Layers Overview

| Layer | Name         | What It Does                          | Example              |
|-------|--------------|---------------------------------------|----------------------|
| 7     | Application  | User-level network communication      | HTTP, DNS            |
| 6     | Presentation | Data encryption & formatting          | TLS/SSL              |
| 5     | Session      | Maintains connection sessions         | Login session        |
| 4     | Transport    | Application communication via ports   | TCP, UDP             |
| 3     | Network      | Packet routing using IP               | IP address           |
| 2     | Data Link    | Communication inside local network    | MAC address          |
| 1     | Physical     | Transmits bits through hardware       | Cables, WiFi         |

---

## Layer-by-Layer Explanation

### 7️⃣ Application Layer

The Application Layer is where **applications communicate with the network**. It defines the protocols used by applications.

**Protocols:** HTTP, HTTPS, DNS, FTP, SMTP

**Example requests:**
```
GET  /products
POST /login
```

> Opening a website in your browser.

---

### 6️⃣ Presentation Layer

The Presentation Layer **formats and encrypts data** before transmission.

**Responsibilities:**
- Encryption
- Compression
- Data formatting

**Protocol:** TLS/SSL (HTTPS encryption)

> Browser encrypts data before sending it to a website.

---

### 5️⃣ Session Layer

The Session Layer **manages sessions** between two communicating systems.

**Responsibilities:**
- Establish session
- Maintain session
- Terminate session

**Examples:**
- User login session
- Database connection session
- Video call session

> User logs into a website and remains authenticated throughout.

---

### 4️⃣ Transport Layer

The Transport Layer controls **communication between applications using ports**.

**Protocols:** TCP, UDP

```
192.168.1.50:80      ← port 80 = HTTP
192.168.1.50:3306    ← port 3306 = MySQL
```

> **IP → identifies the machine | Port → identifies the application**

**Common ports:**

| Service | Port |
|---------|------|
| HTTP    | 80   |
| HTTPS   | 443  |
| SSH     | 22   |
| MySQL   | 3306 |

```
Browser → Server:443 (HTTPS)
```

---

### 3️⃣ Network Layer

The Network Layer is responsible for **routing packets using IP addresses**.

**Responsibilities:**
- IP addressing
- Packet routing
- Path determination

```bash
ping 8.8.8.8
```

```
192.168.1.10  ─────►  192.168.1.50
```

**In Kubernetes:**
```
Pod A  ─────►  Pod B   (L3 communication)
```

---

### 2️⃣ Data Link Layer

The Data Link Layer handles **communication within the same local network** using MAC addresses.

**Example MAC address:**
```
00:1A:2B:3C:4D:5E
```

**Protocols:** Ethernet, ARP

**Example devices:**
```
Laptop → Switch
Server → Router
```

> Your laptop sends a packet to your home router using MAC addressing.

---

### 1️⃣ Physical Layer

The Physical Layer **transmits raw bits through hardware**.

**Examples:**
- Ethernet cable
- Fiber optic cable
- WiFi signals
- Network cards

```
Data transmitted: 0s and 1s
```

> Electrical signals traveling through a network cable.

---

## How All Layers Work Together

When you open `https://google.com`, all layers work like this:

| Layer | What Happens                            |
|-------|-----------------------------------------|
| 7 — Application  | Browser sends HTTP request     |
| 6 — Presentation | Data encrypted using TLS       |
| 5 — Session      | Session established            |
| 4 — Transport    | TCP connection created         |
| 3 — Network      | Packet routed using IP         |
| 2 — Data Link    | MAC address used inside LAN    |
| 1 — Physical     | Data transmitted via cable/WiFi|

---

## Important Layers for DevOps / Kubernetes

In cloud and Kubernetes networking, we mainly deal with three layers:

| Layer | Role in Kubernetes          | Example                  |
|-------|-----------------------------|--------------------------|
| L3    | Pod IP communication        | Pod A → Pod B via IP     |
| L4    | Service port routing        | Service:80 → Pod:8080    |
| L7    | Ingress HTTP routing        | /products, /login paths  |

**Example flow:**
```
Client
  ↓
Ingress (L7)   ← routes by HTTP path
  ↓
Service (L4)   ← routes by port
  ↓
Pod IP (L3)    ← routes by IP
```

---

## Quick Interview Summary

| Layer | What it handles                        | Example        |
|-------|----------------------------------------|----------------|
| L3    | IP communication between hosts         | `ping 8.8.8.8` |
| L4    | Port communication between applications| `curl :443`    |
| L7    | Application-level (HTTP, APIs)         | REST API call  |

> `ping` → Layer 3 | `curl` → Layer 4 | `HTTP API` → Layer 7
