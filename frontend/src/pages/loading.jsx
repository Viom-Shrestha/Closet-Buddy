import React, { useState, useEffect } from 'react';
import { Sparkles, Shirt } from 'lucide-react';

export default function ClosetBuddyLoader() {
    const [progress, setProgress] = useState(0);
    const [loadingText, setLoadingText] = useState('Organizing your wardrobe');

    const loadingMessages = [
        'Organizing your wardrobe',
        'Analyzing your style',
        'Curating outfit ideas',
        'Preparing your closet',
        'Almost ready'
    ];

    // Progress increment
    useEffect(() => {
        const progressInterval = setInterval(() => {
            setProgress(prev => {
                if (prev >= 100) {
                    clearInterval(progressInterval);
                    return 100;
                }
                return prev + 1;
            });
        }, 30);
        return () => clearInterval(progressInterval);
    }, []);

    // Loading messages
    useEffect(() => {
        const messageInterval = setInterval(() => {
            setLoadingText(prev => {
                const currentIndex = loadingMessages.indexOf(prev);
                const nextIndex = (currentIndex + 1) % loadingMessages.length;
                return loadingMessages[nextIndex];
            });
        }, 2000);
        return () => clearInterval(messageInterval);
    }, []);

    return (
        <div className="w-screen min-h-screen bg-gradient-to-br from-rose-50 via-purple-50 to-indigo-100 flex items-center justify-center overflow-hidden relative">

            {/* Large Animated background blobs */}
            <div className="absolute inset-0 overflow-hidden">
                <div className="absolute top-24 left-24 w-96 h-96 bg-purple-300 rounded-full mix-blend-multiply filter blur-3xl opacity-50 animate-pulse"></div>
                <div className="absolute top-36 right-24 w-96 h-96 bg-rose-300 rounded-full mix-blend-multiply filter blur-3xl opacity-50 animate-pulse" style={{ animationDelay: '1s' }}></div>
                <div className="absolute bottom-24 left-1/2 w-96 h-96 bg-indigo-300 rounded-full mix-blend-multiply filter blur-3xl opacity-50 animate-pulse" style={{ animationDelay: '2s' }}></div>
            </div>

            {/* Main content */}
            <div className="relative z-10 text-center">

                {/* Logo */}
                <div className="mb-12 relative inline-block">
                    <div className="absolute inset-0 bg-gradient-to-r from-purple-500 to-pink-500 rounded-full blur-2xl opacity-50 animate-pulse"></div>
                    <div className="relative bg-white rounded-full p-12 shadow-2xl">
                        <Shirt className="w-32 h-32 text-purple-600" strokeWidth={1.5} />
                        <Sparkles className="w-8 h-8 text-rose-400 absolute -top-4 -right-4 animate-bounce" />
                    </div>
                </div>

                {/* Brand */}
                <h1 className="text-7xl font-bold mb-4 bg-gradient-to-r from-purple-700 via-pink-600 to-indigo-700 bg-clip-text text-transparent">
                    Closet Buddy
                </h1>
                <p className="text-2xl text-gray-700 mb-16">Your AI-Powered Style Assistant</p>

                {/* Progress bar */}
                <div className="w-2/3 mx-auto mb-8">
                    <div className="h-4 bg-white/50 rounded-full overflow-hidden backdrop-blur-sm shadow-inner">
                        <div
                            className="h-full bg-gradient-to-r from-purple-600 via-pink-600 to-indigo-600 rounded-full relative overflow-hidden transition-all duration-300 ease-out"
                            style={{ width: `${progress}%` }}
                        >
                            <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/30 to-transparent animate-shimmer"></div>
                        </div>
                    </div>
                </div>

                {/* Loading text */}
                <p className="text-2xl font-medium text-gray-800 mb-4">
                    {loadingText}<span className="ml-2 animate-pulse">...</span>
                </p>

                {/* Percentage */}
                <p className="text-5xl font-bold bg-gradient-to-r from-purple-700 to-pink-700 bg-clip-text text-transparent">
                    {progress}%
                </p>
            </div>

            {/* Shimmer animation */}
            <style jsx>{`
        @keyframes shimmer {
          0% { transform: translateX(-100%); }
          100% { transform: translateX(100%); }
        }
        .animate-shimmer {
          animation: shimmer 2s infinite;
        }
      `}</style>
        </div>
    );
}
