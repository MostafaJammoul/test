import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import apiClient from '../services/api';
import Button from '../components/common/Button';
import Card from '../components/common/Card';

export default function MFASetup() {
  const [qrCode, setQrCode] = useState('');
  const [secret, setSecret] = useState('');
  const [code, setCode] = useState('');
  const [loading, setLoading] = useState(true);
  const [verifying, setVerifying] = useState(false);
  const [error, setError] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    // Fetch QR code from backend
    const fetchQRCode = async () => {
      try {
        const response = await apiClient.get('/authentication/mfa/setup/');
        setQrCode(response.data.qr_code);
        setSecret(response.data.secret);
        setLoading(false);
      } catch (err) {
        setError(err.response?.data?.error || 'Failed to generate QR code');
        setLoading(false);
      }
    };

    fetchQRCode();
  }, []);

  const handleVerify = async (e) => {
    e.preventDefault();
    setError('');
    setVerifying(true);

    try {
      await apiClient.post('/authentication/mfa/setup/', { code });
      // MFA setup successful, redirect to MFA challenge to verify immediately
      navigate('/mfa-challenge');
    } catch (err) {
      setError(err.response?.data?.error || 'Invalid code. Please try again.');
      setVerifying(false);
      setCode('');
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-gray-50">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    );
  }

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full">
        <div className="text-center mb-8">
          <h2 className="text-3xl font-bold text-gray-900">
            Setup Multi-Factor Authentication
          </h2>
          <p className="mt-2 text-sm text-gray-600">
            Scan the QR code with your authenticator app
          </p>
        </div>

        <Card>
          <div className="space-y-6">
            {/* QR Code */}
            <div className="flex justify-center">
              {qrCode && (
                <img
                  src={qrCode}
                  alt="MFA QR Code"
                  className="w-64 h-64 border border-gray-300 rounded-lg"
                />
              )}
            </div>

            {/* Instructions */}
            <div className="bg-blue-50 border border-blue-200 rounded-md p-4">
              <h3 className="text-sm font-medium text-blue-900 mb-2">
                Instructions:
              </h3>
              <ol className="text-sm text-blue-800 space-y-1 list-decimal list-inside">
                <li>Open Google Authenticator, Authy, or Microsoft Authenticator</li>
                <li>Tap "Add Account" or "+"</li>
                <li>Scan the QR code above</li>
                <li>Enter the 6-digit code shown in the app below</li>
              </ol>
            </div>

            {/* Manual Entry Secret */}
            <div className="bg-gray-50 border border-gray-200 rounded-md p-4">
              <p className="text-xs text-gray-600 mb-1">
                Can't scan? Enter this code manually:
              </p>
              <code className="text-sm font-mono bg-white px-2 py-1 rounded border border-gray-300 block break-all">
                {secret}
              </code>
            </div>

            {/* Verification Form */}
            <form onSubmit={handleVerify} className="space-y-4">
              <div>
                <label htmlFor="code" className="block text-sm font-medium text-gray-700 mb-2">
                  Enter Verification Code
                </label>
                <input
                  id="code"
                  type="text"
                  inputMode="numeric"
                  pattern="[0-9]{6}"
                  maxLength={6}
                  required
                  value={code}
                  onChange={(e) => setCode(e.target.value.replace(/\D/g, ''))}
                  className="block w-full text-center text-2xl tracking-widest rounded-md border-gray-300 shadow-sm focus:border-primary-500 focus:ring-primary-500"
                  placeholder="000000"
                  disabled={verifying}
                />
              </div>

              {error && (
                <div className="bg-red-50 border border-red-200 rounded-md p-3">
                  <p className="text-sm text-red-800">{error}</p>
                </div>
              )}

              <Button
                type="submit"
                className="w-full"
                disabled={verifying || code.length !== 6}
              >
                {verifying ? 'Verifying...' : 'Verify and Enable MFA'}
              </Button>
            </form>

            {/* Security Note */}
            <div className="text-xs text-gray-500 text-center">
              <p>
                🔒 Your secret key is stored securely and encrypted in the database.
                Keep your authenticator app safe.
              </p>
            </div>
          </div>
        </Card>
      </div>
    </div>
  );
}
