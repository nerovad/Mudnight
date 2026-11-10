// src/utils/useApi.ts - Simplified version
interface ApiOptions {
  requireAuth?: boolean;
}

export const useApi = (options: ApiOptions = { requireAuth: true }) => {
  const getHeaders = () => {
    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
    };

    if (options.requireAuth) {
      const token = localStorage.getItem('token');
      if (token) {
        headers['Authorization'] = `Bearer ${token}`;
      }
    }

    return headers;
  };

  const handleResponse = async (response: Response) => {
    if (response.status === 401 && options.requireAuth) {
      // Token expired, clear it
      localStorage.removeItem('token');
      // Trigger storage event to update other components
      window.dispatchEvent(new Event('storage'));
      throw new Error('Authentication expired');
    }

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Network error' }));
      throw new Error(error.error || `HTTP ${response.status}`);
    }

    return response.json();
  };

  const get = async <T>(url: string, fallback?: T): Promise<T> => {
    try {
      const response = await fetch(url, {
        method: 'GET',
        headers: getHeaders(),
      });
      return await handleResponse(response);
    } catch (error) {
      if (fallback !== undefined) {
        return fallback;
      }
      throw error;
    }
  };

  const post = async <T>(url: string, data: any): Promise<T> => {
    const response = await fetch(url, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify(data),
    });
    return await handleResponse(response);
  };

  return { get, post };
};
