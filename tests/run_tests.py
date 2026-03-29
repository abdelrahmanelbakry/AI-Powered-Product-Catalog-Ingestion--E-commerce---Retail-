#!/usr/bin/env python3
"""
Test Runner for AI-Powered Product Catalog Ingestion Pipeline
"""

import sys
import os
import subprocess
import argparse
from pathlib import Path

def run_command(cmd, cwd=None):
    """Run a command and return the result"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=cwd,
            capture_output=True,
            text=True,
            check=True
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.CalledProcessError as e:
        return e.returncode, e.stdout, e.stderr

def install_dependencies():
    """Install test dependencies"""
    print("📦 Installing test dependencies...")
    
    dependencies = [
        "pytest>=7.0.0",
        "pytest-cov>=4.0.0",
        "pytest-mock>=3.10.0",
        "pytest-xdist>=3.0.0",
        "coverage>=7.0.0",
        "pytest-html>=3.1.0"
    ]
    
    for dep in dependencies:
        print(f"  Installing {dep}...")
        code, stdout, stderr = run_command(f"pip install {dep}")
        if code != 0:
            print(f"❌ Failed to install {dep}: {stderr}")
            return False
    
    print("✅ Dependencies installed successfully")
    return True

def run_unit_tests(verbose=False, coverage=False):
    """Run unit tests"""
    print("🧪 Running unit tests...")
    
    test_dir = Path(__file__).parent
    cmd = ["python", "-m", "pytest"]
    
    if verbose:
        cmd.append("-v")
    
    if coverage:
        cmd.extend([
            "--cov=../lambda",
            "--cov-report=html",
            "--cov-report=term-missing",
            "--cov-fail-under=80"
        ])
    
    cmd.extend([
        str(test_dir),
        "-m", "not integration and not bedrock and not database"
    ])
    
    code, stdout, stderr = run_command(" ".join(cmd), cwd=test_dir)
    
    print(stdout)
    if stderr:
        print(f"Stderr: {stderr}")
    
    if code == 0:
        print("✅ Unit tests passed")
        return True
    else:
        print("❌ Unit tests failed")
        return False

def run_integration_tests(verbose=False):
    """Run integration tests"""
    print("🔗 Running integration tests...")
    
    test_dir = Path(__file__).parent
    cmd = ["python", "-m", "pytest"]
    
    if verbose:
        cmd.append("-v")
    
    cmd.extend([
        str(test_dir),
        "-m", "integration"
    ])
    
    code, stdout, stderr = run_command(" ".join(cmd), cwd=test_dir)
    
    print(stdout)
    if stderr:
        print(f"Stderr: {stderr}")
    
    if code == 0:
        print("✅ Integration tests passed")
        return True
    else:
        print("❌ Integration tests failed")
        return False

def run_all_tests(verbose=False, coverage=False):
    """Run all tests"""
    print("🚀 Running all tests...")
    
    test_dir = Path(__file__).parent
    cmd = ["python", "-m", "pytest"]
    
    if verbose:
        cmd.append("-v")
    
    if coverage:
        cmd.extend([
            "--cov=../lambda",
            "--cov-report=html",
            "--cov-report=term-missing",
            "--cov-fail-under=80"
        ])
    
    cmd.append(str(test_dir))
    
    code, stdout, stderr = run_command(" ".join(cmd), cwd=test_dir)
    
    print(stdout)
    if stderr:
        print(f"Stderr: {stderr}")
    
    if code == 0:
        print("✅ All tests passed")
        return True
    else:
        print("❌ Some tests failed")
        return False

def run_specific_test(test_file, verbose=False):
    """Run a specific test file"""
    print(f"🎯 Running {test_file}...")
    
    test_dir = Path(__file__).parent
    test_path = test_dir / test_file
    
    if not test_path.exists():
        print(f"❌ Test file {test_file} not found")
        return False
    
    cmd = ["python", "-m", "pytest"]
    
    if verbose:
        cmd.append("-v")
    
    cmd.append(str(test_path))
    
    code, stdout, stderr = run_command(" ".join(cmd), cwd=test_dir)
    
    print(stdout)
    if stderr:
        print(f"Stderr: {stderr}")
    
    if code == 0:
        print(f"✅ {test_file} passed")
        return True
    else:
        print(f"❌ {test_file} failed")
        return False

def generate_coverage_report():
    """Generate HTML coverage report"""
    print("📊 Generating coverage report...")
    
    test_dir = Path(__file__).parent
    cmd = [
        "python", "-m", "pytest",
        "--cov=../lambda",
        "--cov-report=html",
        "--cov-report=term-missing",
        str(test_dir)
    ]
    
    code, stdout, stderr = run_command(" ".join(cmd), cwd=test_dir)
    
    if code == 0:
        print("✅ Coverage report generated")
        print("📁 Open htmlcov/index.html to view the report")
        return True
    else:
        print("❌ Failed to generate coverage report")
        return False

def lint_code():
    """Run code linting"""
    print("🔍 Running code linting...")
    
    # Check if flake8 is installed
    try:
        code, stdout, stderr = run_command("flake8 --version")
    except:
        print("📦 Installing flake8...")
        install_code, install_stdout, install_stderr = run_command("pip install flake8")
        if install_code != 0:
            print("❌ Failed to install flake8")
            return False
    
    # Lint lambda functions
    lambda_dirs = [
        Path(__file__).parent.parent / "lambda" / "ingestion",
        Path(__file__).parent.parent / "lambda" / "processing"
    ]
    
    all_passed = True
    for lambda_dir in lambda_dirs:
        if lambda_dir.exists():
            print(f"  Linting {lambda_dir.name}...")
            code, stdout, stderr = run_command(f"flake8 {lambda_dir} --max-line-length=100 --ignore=E203,W503")
            if code != 0:
                print(f"❌ Linting failed for {lambda_dir.name}")
                print(stderr)
                all_passed = False
            else:
                print(f"✅ {lambda_dir.name} linted successfully")
    
    if all_passed:
        print("✅ Code linting passed")
        return True
    else:
        print("❌ Code linting failed")
        return False

def main():
    """Main test runner"""
    parser = argparse.ArgumentParser(description="Test runner for Product Catalog Pipeline")
    parser.add_argument(
        "--type",
        choices=["unit", "integration", "all", "coverage", "lint"],
        default="all",
        help="Type of tests to run"
    )
    parser.add_argument(
        "--file",
        help="Specific test file to run"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Verbose output"
    )
    parser.add_argument(
        "--coverage", "-c",
        action="store_true",
        help="Generate coverage report"
    )
    parser.add_argument(
        "--install-deps",
        action="store_true",
        help="Install test dependencies"
    )
    
    args = parser.parse_args()
    
    print("🚀 Product Catalog Pipeline Test Runner")
    print("=" * 50)
    
    # Install dependencies if requested
    if args.install_deps:
        if not install_dependencies():
            sys.exit(1)
    
    # Run specific test file
    if args.file:
        success = run_specific_test(args.file, args.verbose)
        sys.exit(0 if success else 1)
    
    # Run based on test type
    success = True
    
    if args.type == "unit":
        success = run_unit_tests(args.verbose, args.coverage)
    elif args.type == "integration":
        success = run_integration_tests(args.verbose)
    elif args.type == "coverage":
        success = generate_coverage_report()
    elif args.type == "lint":
        success = lint_code()
    elif args.type == "all":
        success = run_all_tests(args.verbose, args.coverage)
    
    print("=" * 50)
    if success:
        print("🎉 All tests completed successfully!")
        sys.exit(0)
    else:
        print("💥 Some tests failed!")
        sys.exit(1)

if __name__ == "__main__":
    main()
