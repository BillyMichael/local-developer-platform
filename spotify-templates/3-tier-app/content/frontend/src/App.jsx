import { useState, useEffect } from 'react'

function App() {
  const [data, setData] = useState(null);

  useEffect(() => {
    fetch('/api/data')
      .then(res => res.json())
      .then(data => setData(data));
  }, []);

  return (
    <>
      <h1>${{ values.component_id }}</h1>
      <div className="card">
        <h2>Data from Backend:</h2>
        <pre>{JSON.stringify(data, null, 2)}</pre>
      </div>
    </>
  )
}

export default App
