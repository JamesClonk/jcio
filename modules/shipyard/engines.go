package main

type Engine struct {
	ID             string        `json:"id,omitempty"`
	SSLCertificate string        `json:"ssl_cert,omitempty"`
	SSLKey         string        `json:"ssl_key,omitempty"`
	CACertificate  string        `json:"ca_cert,omitempty"`
	Engine         EngineOptions `json:"engine,omitempty"`
}

type EngineOptions struct {
	ID      string   `json:"id,omitempty"`
	Address string   `json:"addr,omitempty"`
	Cpus    float64  `json:"cpus,omitempty"`
	Memory  float64  `json:"memory,omitempty"`
	Labels  []string `json:"labels,omitempty"`
}

func (c *Client) AddEngine(id, sslcert, sslkey, cacert, url string, cpu, memory float64) error {
	engine = &Engine{
		ID:             id,
		SSLCertificate: sslcert,
		SSLKey:         sslkey,
		CACertificate:  cacert,
		Engine: EngineOptions{
			ID:      id,
			Labels:  []string{id},
			Address: url,
			Cpus:    cpu,
			Memory:  memory,
		},
	}
	if err := c.post(201, "/api/engines", engine, nil); err != nil {
		return err
	}
	return nil
}
