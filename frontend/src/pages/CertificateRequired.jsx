export default function CertificateRequired() {
  const hostname = typeof window !== 'undefined' ? window.location.host : 'your-domain';

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 px-4">
      <div className="max-w-xl w-full bg-white shadow-md rounded-lg p-8 text-center">
        <h1 className="text-2xl font-semibold text-gray-900 mb-4">
          Certificate Authentication Required
        </h1>
        <p className="text-gray-600 mb-4">
          This portal uses mutual TLS (mTLS) for investigators, auditors, and court users.
          Import your issued <code>.p12</code> certificate into your browser and refresh this page
          to continue. After the certificate is accepted you will be prompted for MFA.
        </p>
        <div className="bg-primary-50 text-primary-700 rounded-md p-4 mb-4 text-left">
          <p className="font-medium">Need a certificate?</p>
          <p className="text-sm">
            Administrators can issue certificates from the Admin &rarr; Certificates tab, or request one
            from your security team. Refer to the deployment guide for installation steps.
          </p>
        </div>
        <p className="text-gray-600 text-sm">
          If you are the system administrator and need to log in with a password, open{' '}
          <a href="/admin" className="text-primary-600 font-medium hover:underline">
            https://{hostname}/admin
          </a>{' '}
          instead. Password login is restricted to administrators only.
        </p>
      </div>
    </div>
  );
}
