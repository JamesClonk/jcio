package main

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
)

type Client struct {
	client    *http.Client
	UserAgent string
	Endpoint  *url.URL
	Token     string
	Username  string
}

func NewClient(endpoint string) *Client {
	ep, err := url.Parse(endpoint)
	if err != nil {
		log.Fatal(err)
	}
	tr := &http.Transport{
		TLSClientConfig: &tls.Config{
			InsecureSkipVerify: true,
		},
	}
	return &Client{
		UserAgent: "configure-shipyard-go",
		client:    &http.Client{Transport: tr},
		Endpoint:  ep,
	}
}

func (c *Client) get(expectedCode int, path string, data interface{}) error {
	req, err := c.newRequest("GET", path, nil)
	if err != nil {
		return err
	}
	return c.do(expectedCode, req, data)
}

func (c *Client) post(expectedCode int, path string, values interface{}, data interface{}) error {
	b, err := json.Marshal(values)
	if err != nil {
		return err
	}
	req, err := c.newRequest("POST", path, bytes.NewBuffer(b))
	if err != nil {
		return err
	}
	return c.do(expectedCode, req, data)
}

func (c *Client) delete(expectedCode int, path string, values interface{}, data interface{}) error {
	b, err := json.Marshal(values)
	if err != nil {
		return err
	}
	req, err := c.newRequest("DELETE", path, bytes.NewBuffer(b))
	if err != nil {
		return err
	}
	return c.do(expectedCode, req, data)
}

func (c *Client) do(expectedCode int, req *http.Request, data interface{}) error {
	resp, err := c.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if err := checkResponse(expectedCode, resp); err != nil {
		return err
	}
	if data != nil {
		body, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			return err
		}
		if err := json.Unmarshal(body, data); err != nil {
			return err
		}
	}
	return nil
}

func (c *Client) newRequest(method string, path string, body io.Reader) (*http.Request, error) {
	relPath, err := url.Parse(path)
	if err != nil {
		return nil, err
	}
	url := c.Endpoint.ResolveReference(relPath)
	req, err := http.NewRequest(method, url.String(), body)
	if err != nil {
		return nil, err
	}
	req.Header.Add("User-Agent", c.UserAgent)
	if req.Method == "POST" {
		req.Header.Set("Content-Type", "application/json")
	}
	if c.Token != "" {
		req.Header.Add("X-Access-Token", fmt.Sprintf("%s:%s", c.Username, c.Token))
	}
	return req, nil
}

func checkResponse(expectedCode int, resp *http.Response) error {
	if resp.StatusCode == expectedCode {
		return nil
	}
	data, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	return errors.New(string(data))
}
